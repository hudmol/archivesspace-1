# Support for storing a relationship between two records where the direction of
# the relationship matters.
#
# For example, a relationship between two agents might be called "isParentOf"
# when viewed from one side, and "isChildOf" when viewed from the other.

module DirectionalRelationships


  def self.included(base)
    base.extend(ClassMethods)
  end


  def update_from_json(json, opts = {}, apply_nested_records = true)
    self.class.prepare_directional_relationship_for_storage(json)
    super
  end


  module ClassMethods

    attr_reader :directional_relationships

    def define_directional_relationship(opts)
      @directional_relationships ||= []
      @directional_relationships << opts
    end


    def prepare_directional_relationship_for_storage(json)
      directional_relationships.each do |rel|
        property = rel[:property]

        Array(json[property]).each do |relationship|
          # Relationships are directionless by default, but here we want to
          # store a direction (e.g. A is a child of B)
          #
          # We store the URI that is the subject of this relationship as a separate
          # property to preserve this direction.
          #
          relationship['relationship_target'] = relationship['ref']
        end
      end
    end


    def prepare_directional_relationship_for_display(json)
      directional_relationships.each do |rel|
        property = rel[:property]

        Array(json[property]).each do |relationship|
          if relationship['relationship_target'] == json.uri
            # This means we're looking at the relationship from the other side.
            #
            # For example, if the relationship is "A is a parent of B", then we
            # want:
            #
            #   * 'GET A' to yield  {relator => 'is_parent_of', ref => 'B'}
            #   * 'GET B' to yield  {relator => 'is_child_of', ref => 'A'}
            #
            # So we want to invert the relator for this case.

            relator_values = JSONModel.enum_values(JSONModel(relationship['jsonmodel_type'].intern).schema['properties']['relator']['dynamic_enum'])
            relator_values -= ['other_unmapped'] # grumble.

            if relator_values.length == 2
              # When there are two possible values we assume they're inverses
              # Set the relator to whatever the inverse of the current one is.
              relationship['relator'] = (relator_values - [relationship['relator']]).first
            end
          end
        end
      end
    end



    def create_from_json(json, opts = {})
      prepare_directional_relationship_for_storage(json)
      super
    end


    def sequel_to_jsonmodel(objs, opts = {})
      jsons = super

      jsons.zip(objs).each do |json, obj|
        prepare_directional_relationship_for_display(json)
      end

      jsons
    end

  end



end
