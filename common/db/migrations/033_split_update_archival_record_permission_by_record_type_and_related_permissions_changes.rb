require_relative 'utils'

Sequel.migration do

  up do
    update_archival_record_permission_id = self[:permission].filter(:permission_code => 'update_archival_record').get(:id)

    if update_archival_record_permission_id

      update_accession_permission_id = self[:permission].filter(:permission_code => 'update_accession_record').get(:id)
      if update_accession_permission_id.nil?
        update_accession_permission_id = self[:permission].insert(:permission_code => 'update_accession_record',
                                                                  :description => 'The ability to create and modify accessions records',
                                                                  :level => 'repository',
                                                                  :created_by => 'admin',
                                                                  :last_modified_by => 'admin',
                                                                  :create_time => Time.now,
                                                                  :system_mtime => Time.now,
                                                                  :user_mtime => Time.now)
      end

      update_resource_permission_id = self[:permission].filter(:permission_code => 'update_resource_record').get(:id)
      if update_resource_permission_id.nil?
        update_resource_permission_id = self[:permission].insert(:permission_code => 'update_resource_record',
                                                                 :description => 'The ability to create and modify resource records',
                                                                 :level => 'repository',
                                                                 :created_by => 'admin',
                                                                 :last_modified_by => 'admin',
                                                                 :create_time => Time.now,
                                                                 :system_mtime => Time.now,
                                                                 :user_mtime => Time.now)
      end

      update_digital_object_permission_id = self[:permission].filter(:permission_code => 'update_digital_object_record').get(:id)
      if update_digital_object_permission_id.nil?
        update_digital_object_permission_id = self[:permission].insert(:permission_code => 'update_digital_object_record',
                                                                       :description => 'The ability to create and modify digital object records',
                                                                       :level => 'repository',
                                                                       :created_by => 'admin',
                                                                       :last_modified_by => 'admin',
                                                                       :create_time => Time.now,
                                                                       :system_mtime => Time.now,
                                                                       :user_mtime => Time.now)
      end

      import_permission_id = self[:permission].filter(:permission_code => 'import_records').get(:id)
      if import_permission_id.nil?
        import_permission_id = self[:permission].insert(:permission_code => 'import_records',
                                                        :description => 'The ability to initiate an importer job',
                                                        :level => 'repository',
                                                        :created_by => 'admin',
                                                        :last_modified_by => 'admin',
                                                        :create_time => Time.now,
                                                        :system_mtime => Time.now,
                                                        :user_mtime => Time.now)
      end

      manage_vocabulary_permission_id = self[:permission].filter(:permission_code => 'manage_vocabulary_record').get(:id)
      if manage_vocabulary_permission_id.nil?
        manage_vocabulary_permission_id = self[:permission].insert(:permission_code => 'manage_vocabulary_record',
                                                              :description => 'The ability to create, modify and delete an vocabulary record',
                                                              :level => 'repository',
                                                              :created_by => 'admin',
                                                              :last_modified_by => 'admin',
                                                              :create_time => Time.now,
                                                              :system_mtime => Time.now,
                                                              :user_mtime => Time.now)
      end

      update_archival_record_group_ids = self[:group_permission].filter(:permission_id => [delete_archival_record_permission_id, update_archival_record_permission_id]).select(:group_id).map {|row| row[:group_id]}.uniq
      update_archival_record_group_ids.each do |group_id|
        self[:group_permission].insert(:permission_id => update_accession_permission_id,
                                       :group_id => group_id)
        self[:group_permission].insert(:permission_id => update_resource_permission_id,
                                       :group_id => group_id)
        self[:group_permission].insert(:permission_id => update_digital_object_permission_id,
                                       :group_id => group_id)
        self[:group_permission].insert(:permission_id => import_permission_id,
                                       :group_id => group_id)
        self[:group_permission].insert(:permission_id => manage_vocabulary_permission_id,
                                       :group_id => group_id)
      end

      self[:permission].delete(:permission_id => update_archival_record_permission)
    end
  end

  down do
    # no going back
  end

end

