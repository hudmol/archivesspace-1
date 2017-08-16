require_relative 'converter'
class AssessmentConverter < Converter

  require_relative 'lib/csv_converter'
  include ASpaceImport::CSVConvert

  @booleans = ['basic_accession_report', 'basic_appraisal', 'basic_container_list',
               'basic_catalog_record', 'basic_control_file', 'basic_finding_aid_ead',
               'basic_finding_aid_paper', 'basic_finding_aid_word', 'basic_finding_aid_spreadsheet',
               'basic_sensitive_material', 'basic_review_required']

  # overriding this because we are special
  # this importer is self configuring, so it has to configure itself on each run
  def self.configuration
    self.configure
  end


  def self.configure_cell_handlers(row)
    if row[0] == 'basic'
      # this is the section header row
      @section_headers = row
      @field_headers = []
      @cell_handlers = []
      @defns = nil
      # return empty cell handlers so that #run calls us again
      return [[], []]
    end

    records = 0
    agents = 0
    @field_headers = @section_headers.zip(row).map{|section, field|
      hdr = "#{section}_#{field}"
      if hdr == 'basic_record'
        records += 1
        hdr += "_#{records}"
      elsif hdr == 'basic_surveyed_by'
        agents += 1
        hdr += "_#{agents}"
      end
      # our parent is very strict about headers ...
      normalize_label(hdr.downcase).gsub(/ /, '_')
    }

    super(@field_headers)
  end

  def self.configure
    config = {}    
    records = 0
    agents = 0

    @field_headers.each do |section_field|
      (section, field) = section_field.split('_', 2)
      name = section_field
      data_path = "assessment.#{field}"
      val_filter = @booleans.include?(section_field) ? normalize_boolean : nil

      if section_field.start_with?('basic_record')
        records += 1
        data_path = "records_#{records}.uri"
        val_filter = record_to_uri

        config["records_#{records}".intern] = {
          :record_type => Proc.new {|data|
            JSONModel.parse_reference(data['uri'])[:type]
          },
          :on_row_complete => Proc.new { |cache, record|

            assessment = cache.find {|obj| obj && obj.class.record_type == 'assessment' }

            assessment.records << {'ref' => record.uri}

            # nil the record in the cache to avoid having it created
            cache.map! {|obj| (obj && obj.uri == record.uri) ? nil : obj}
          }
        }


      elsif section_field.start_with?('basic_surveyed_by')
        agents += 1
        data_path = "agents_#{agents}.uri"
        val_filter = user_to_uri

        config["agents_#{agents}".intern] = {
          :record_type => Proc.new {|data|
            JSONModel.parse_reference(data['uri'])[:type]
          },
          :on_row_complete => Proc.new { |cache, agent|

            assessment = cache.find {|obj| obj && obj.class.record_type == 'assessment' }

            assessment.surveyed_by << {'ref' => agent.uri}

            # nil the agent in the cache to avoid having it created
            cache.map! {|obj| (obj && obj.uri == agent.uri) ? nil : obj}
          }
        }

      elsif section == 'format'
        defn = match_definition('format', field)

        data_path = "#{section_field}.value"
        val_filter = boolean_to_s

        config[section_field.intern] = {
          :record_type => 'assessment_attribute',
          :on_row_complete => Proc.new { |cache, attr|
            if attr.value == 'true'
              assessment = cache.find {|obj| obj && obj.class.record_type == 'assessment' }
              assessment.formats << { :value => 'true', :definition_id => defn[:id]  }
            end
          }
        }

      elsif section == 'rating'

        if field.end_with?('_note')
          data_path = section_field.sub(/_note$/, '') + '.note'
        else
          defn = match_definition('rating', field)

          data_path = "#{section_field}.value"

          config[section_field.intern] = {
            :record_type => 'assessment_attribute',
            :on_row_complete => Proc.new { |cache, attr|
              assessment = cache.find {|obj| obj && obj.class.record_type == 'assessment' }
              assessment.formats << {
                :value => attr.value,
                :note => attr.note,
                :definition_id => defn[:id]
              }
            }
          }

        end

      elsif section == 'conservation'
        defn = match_definition('conservation_issue', field)

        data_path = "#{section_field}.value"
        val_filter = boolean_to_s

        config[section_field.intern] = {
          :record_type => 'assessment_attribute',
          :on_row_complete => Proc.new { |cache, attr|
            if attr.value == 'true'
              assessment = cache.find {|obj| obj && obj.class.record_type == 'assessment' }
              assessment.conservation_issues << { :value => 'true', :definition_id => defn[:id]  }
            end
          }
        }
      end

      config[name] = [val_filter, data_path]
    end

    config
  end

  def self.import_types(show_hidden = false)
    [
     {
       :name => "assessment_csv",
       :description => "Import Assessment records from a CSV file"
     }
    ]
  end

  def self.instance_for(type, input_file)
    if type == "assessment_csv"
      self.new(input_file)
    else
      nil
    end
  end


  private


  def self.normalize_label(label)
    label.downcase.gsub(/[^a-z0-9]+/, ' ')
  end


  def self.normalize_boolean
    @normalize_boolean ||= Proc.new {|val| val.to_s.upcase.match(/\A(1|T|Y|YES|TRUE)\Z/) ? true : false }
    @normalize_boolean
  end


  def self.boolean_to_s
    @boolean_to_s ||= Proc.new {|val| val.to_s.upcase.match(/\A(1|T|Y|YES|TRUE)\Z/) ? 'true' : 'false' }
    @boolean_to_s
  end


  def self.record_to_uri
    @record_types ||=  %w{resource archival_object accession digital_object}
    @record_to_uri ||= Proc.new{|val|
      (junk, type, id) = val.downcase.match(/^\s*([a-z_]*?)[_\/\. ]+(\d+)\s*$/).to_a

      unless type && id
        raise "Invalid basic_record reference #{val}. " +
          "Must have the form [#{@record_types.join('|')}][delimiter]id. " +
          "Where [delimiter] can be any of _ / . or space."
      end

      unless @record_types.include?(type)
        raise "Invalid basic_record reference #{val}. " +
          "Record type #{type} not allowed. Must be one of #{@record_types.join(', ')}."
      end

      JSONModel::JSONModel(type.intern).uri_for(id, :repo_id => Thread.current[:request_context][:repo_id])
    }
    @record_to_uri
  end


  def self.user_to_uri
    @user_to_uri ||= Proc.new{|val|
      unless (user = User.find(:username => val))
        raise "User '#{val}' does not exist"
      end
      
      User.to_jsonmodel(user).agent_record['ref']
    }
    @user_to_uri
  end

  def self.match_definition(type, field)
    @defns ||= AssessmentAttributeDefinitions.get(Thread.current[:request_context][:repo_id]).definitions
    type_defns = @defns.select{|d| d[:type] == type}
    matched_defns = type_defns.select{|d| normalize_label(d[:label]).index(field.gsub(/_/, ' '))}

    if matched_defns.empty?
      raise "Unknown #{type} in column header: #{field}. " +
        "Allowed #{type}s for this repository: #{type_defns.map{|d| d[:label]}.join(', ')}"
    end

    if matched_defns.length > 1
      raise "Ambiguous #{type} type in column header: #{field}. " +
        "Matched #{matched_defns.map{|d| d[:label]}.join(', ')}"
    end

    matched_defns.first
  end

end
