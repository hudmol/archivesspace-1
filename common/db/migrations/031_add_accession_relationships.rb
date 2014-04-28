require_relative 'utils'

Sequel.migration do

  up do
    create_enum("accession_parts_relator", ["has_part", "forms_part_of"])
    create_enum("accession_bound_relator", ["bound_with"])

    [:accession_part_rlshp, :accession_bound_rlshp].each do |rlshp|

      create_table(rlshp) do
        primary_key :id

        Integer :accession_id_0
        Integer :accession_id_1

        String :relator, :null => false
        String :relationship_target_record_type, :null => false
        Integer :relationship_target_id, :null => false
        String :jsonmodel_type, :null => false

        Integer :aspace_relationship_position

        apply_mtime_columns(false)
      end


      alter_table(rlshp) do
        add_foreign_key([:accession_id_0], :accession, :key => :id)
        add_foreign_key([:accession_id_1], :accession, :key => :id)
      end

    end
  end
end
