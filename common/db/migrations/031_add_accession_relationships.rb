require_relative 'utils'

Sequel.migration do

  up do
    create_enum("accession_parts_relator", ["has_part", "forms_part_of"])


    create_table(:accession_part_rlshp) do
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


    alter_table(:accession_part_rlshp) do
      add_foreign_key([:accession_id_0], :accession, :key => :id)
      add_foreign_key([:accession_id_1], :accession, :key => :id)
    end

  end

end
