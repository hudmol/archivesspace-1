require 'record_inheritance'

require_relative 'periodic_indexer'
require_relative 'large_tree_doc_indexer'

require 'set'

class PUIIndexer < PeriodicIndexer

  PUI_RESOLVES = [
    'ancestors',
    'ancestors::linked_agents',
    'ancestors::subjects',
    'ancestors::instances::sub_container::top_container'
  ]

  def initialize(backend = nil, state = nil, name)
    state_class = AppConfig[:index_state_class].constantize
    index_state = state || state_class.new("indexer_pui_state")

    super(backend, index_state, name)

    # Set up our JSON schemas now that we know the JSONModels have been loaded
    RecordInheritance.prepare_schemas

    @time_to_sleep = AppConfig[:pui_indexing_frequency_seconds].to_i
    @thread_count = AppConfig[:pui_indexer_thread_count].to_i
    @records_per_thread = AppConfig[:pui_indexer_records_per_thread].to_i

    @unpublished_records = java.util.Collections.synchronizedList(java.util.ArrayList.new)
  end

  def fetch_records(type, ids, resolve)
    records = JSONModel(type).all(:id_set => ids.join(","), 'resolve[]' => resolve)
    if RecordInheritance.has_type?(type)
      RecordInheritance.merge(records, :direct_only => true)
    else
      records
    end
  end

  def self.get_indexer(state = nil, name = "PUI Indexer")
    indexer = self.new(state, name)
  end

  def resolved_attributes
    super + PUI_RESOLVES
  end

  PUI_RECORD_TYPES = [
    :accession,
    :resource,
    :archival_object,
    :digital_object,
    :digital_object_component,
    :classification,
    :classification_term,
    :agent_person,
    :agent_corporate_entity,
    :subject,
    :repository,
  ]

  def record_types
    PUI_RECORD_TYPES
  end

  def configure_doc_rules
    super

    record_has_children('resource')
    record_has_children('archival_object')
    record_has_children('digital_object')
    record_has_children('digital_object_component')
    record_has_children('classification')
    record_has_children('classification_term')


    add_document_prepare_hook {|doc, record|
      doc['types'] ||= []
      doc['types'] << 'pui'

      parent_id = doc['id']
      doc['id'] = "#{parent_id}#pui"
      doc['pui_parent_id'] = parent_id

      # p ['pui', doc['id']]

      doc['types'] << "pui_#{doc['primary_type']}"
      doc['types'] << 'pui_record'
      doc['types'] << 'pui_only'

      if ['agent_person', 'agent_corporate_entity'].include?(doc['primary_type'])
        doc['types'] << 'pui_agent'
      end

      if ['resource'].include?(doc['primary_type'])
        doc['types'] << 'pui_collection'
      elsif ['classification'].include?(doc['primary_type'])
        doc['types'] << 'pui_record_group'
      elsif ['agent_person'].include?(doc['primary_type'])
        doc['types'] << 'pui_person'
      elsif doc['primary_type'] == 'top_container'
        doc['types'] << 'pui_container'
      end
    }

    # this runs after the hooks in indexer_common, so we can overwrite with confidence
    add_document_prepare_hook {|doc, record|
      if RecordInheritance.has_type?(doc['primary_type'])
        # special handling for json because we need to include indirectly inherited
        # fields too - the json sent to indexer_common only has directly inherited
        # fields because only they should be indexed.
        # so we remerge without the :direct_only flag, and we remove the ancestors
        doc['json'] = ASUtils.to_json(RecordInheritance.merge(record['record'],
                                                              :remove_ancestors => true))

        # special handling for title because it is populated from display_string
        # in indexer_common and display_string is not changed in the merge process
        doc['title'] = record['record']['title'] if record['record']['title']

        # special handling for fullrecord because we don't want the ancestors indexed.
        # we're now done with the ancestors, so we can just delete them from the record
        record['record'].delete('ancestors')
        doc['fullrecord'] = IndexerCommon.build_fullrecord(record)
      end
    }
  end

  def add_infscroll_docs(resource_uris, batch)
    resource_uris.each do |resource_uri|
      json = JSONModel::HTTP.get_json(resource_uri + '/ordered_records')

      batch << {
        'id' => "#{resource_uri}/ordered_records",
        'pui_parent_id' => resource_uri,
        'publish' => "true",
        'primary_type' => "resource_ordered_records",
        'json' => ASUtils.to_json(json)
      }
    end
  end

  def skip_index_record?(record)
    published = !!record['record']['publish']

    if record['record'].has_key?('has_unpublished_ancestor') && !!record['record']['has_unpublished_ancestor']
      published = false
    end

    if record['record'].has_key?('has_unpublished_ancestor') && !!record['record']['has_unpublished_ancestor']
      published = false
    end

    if record['record'].has_key?('used_within_published_repositories') && !record['record']['used_within_published_repositories']
      published = false
    end

    if record['record'].has_key?('is_linked_to_published_record') && !record['record']['is_linked_to_published_record']
      published = false
    end

    stage_unpublished_for_deletion("#{record['record']['uri']}#pui") unless published

    !published
  end


  def skip_index_doc?(doc)
    published = doc['publish']

    stage_unpublished_for_deletion(doc['id']) unless published

    !published
  end

  def index_round_complete(repository)
    # Index any trees in `repository`
    tree_types = [[:resource, :archival_object],
                  [:digital_object, :digital_object_component],
                  [:classification, :classification_term]]

    start = Time.now
    checkpoints = []

    tree_uris = []

    tree_types.each do |pair|
      root_type = pair.first
      node_type = pair.last

      checkpoints << [repository, root_type, start]
      checkpoints << [repository, node_type, start]

      last_root_node_mtime = [@state.get_last_mtime(repository.id, root_type) - @window_seconds, 0].max
      last_node_mtime = [@state.get_last_mtime(repository.id, node_type) - @window_seconds, 0].max

      root_node_ids = Set.new(JSONModel::HTTP.get_json(JSONModel(root_type).uri_for, :all_ids => true, :modified_since => last_root_node_mtime))
      node_ids = JSONModel::HTTP.get_json(JSONModel(node_type).uri_for, :all_ids => true, :modified_since => last_node_mtime)

      node_ids.each_slice(@records_per_thread) do |ids|
        node_records = JSONModel(node_type).all(:id_set => ids.join(","), 'resolve[]' => [])

        node_records.each do |record|
          root_node_ids << JSONModel.parse_reference(record[root_type.to_s]['ref']).fetch(:id)
        end
      end

      tree_uris.concat(root_node_ids.map {|id| JSONModel(root_type).uri_for(id) })
    end

    batch = IndexBatch.new

    add_infscroll_docs(tree_uris.select {|uri| JSONModel.parse_reference(uri).fetch(:type) == 'resource'},
                       batch)

    LargeTreeDocIndexer.new(batch).add_largetree_docs(tree_uris)

    if batch.length > 0
      log "Indexed #{batch.length} additional PUI records in repository #{repository.repo_code}"

      index_batch(batch, nil, :parent_id_field => 'pui_parent_id')
      send_commit
    end

    handle_deletes(:parent_id_field => 'pui_parent_id')

    # Delete any unpublished records and decendents
    delete_records(@unpublished_records, :parent_id_field => 'pui_parent_id')
    @unpublished_records.clear()

    checkpoints.each do |repository, type, start|
      @state.set_last_mtime(repository.id, type, start)
    end

  end

  def stage_unpublished_for_deletion(doc_id)
    @unpublished_records.add(doc_id) if doc_id =~ /#pui$/
  end
end
