module RecordHelper

  def record_for_type(result, full = false)
    klass = record_class_for_type(result.fetch('primary_type'))
    klass.new(result, full)
  end


  def record_class_for_type(type)

    case type
    when 'resource'
      Resource
    when 'resource_ordered_records'
      ResourceOrderedRecords
    when 'archival_object'
      ArchivalObject
    when 'accession'
      Accession
    when 'digital_object'
      DigitalObject
    when 'digital_object_component'
      DigitalObjectComponent
    when 'classification'
      Classification
    when 'classification_term'
      ClassificationTerm
    when 'subject'
      Subject
    when 'top_container'
      Container
    when 'agent_person'
      AgentPerson
    when 'agent_family'
      AgentFamily
    when 'agent_corporate_entity'
      AgentCorporateEntity
    else
      Record
    end
  end

  def record_from_resolved_json(json, full = false)
    record_for_type({
                      'json' => json,
                      'primary_type' => json.fetch('jsonmodel_type'),
                      'uri' => json.fetch('uri')
                    }, full)
  end

  def icon_for_type(primary_type)
    case primary_type
        when 'repository'
        'fa fa-home'
        when  'resource'
        'yc yc-collection'
        when 'archival_object'
        'fa fa-file-o'
        when 'digital_object'
        'fa fa-th'
        when 'accession'
        'fa fa-yale-accession'
        when 'subject'
        'fa fa-tag'
        when  'agent_person'
        'fa fa-user'
        when 'agent_corporate_entity'
        'fa fa-university'
        when 'agent_family'
        'fa fa-users'
        when 'agent_software'
        'fa fa-save'
        when 'classification'
        'fa fa-sitemap'
        when 'top_container'
        'fa fa-archive'
        when 'digital_object_component'
        'fa fa-th-large'
        else
        'fa fa-square'
      end
  end

  def badge_for_type(primary_type)
    "<span class='record-type-badge #{primary_type}' aria-hidden='true'> \
      <i class='#{icon_for_type(primary_type)}'></i> \
    </span>".html_safe
  end

  def scroll_view_notes_order
    AppConfig[:pui_scroll_view_notes_order]
  end

end
