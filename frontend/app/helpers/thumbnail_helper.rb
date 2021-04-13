module ThumbnailHelper
  def thumbnail_available?(record)
    file_versions = fetch_file_versions(record)

    !file_versions.empty?
  end

  def fetch_representative(file_versions)
    file_versions.detect{|fv| !!fv['is_representative']}
  end

  def fetch_thumbnail(record)
    file_versions = fetch_file_versions(record)

    fetch_representative(file_versions) ||
      ASUtils.wrap(file_versions).detect{|fv| fv['use_statement'] == 'image-thumbnail'} ||
        ASUtils.wrap(file_versions).first
  end

  def file_version_is_image?(file_version)
    begin
      uri = URI(file_version['file_uri'])
      if ['jpeg', 'gif'].include?(file_version['file_format_name']) && FileEmbedHelper.supported_scheme?(uri.scheme)
        true
      else
        false
      end
    rescue
      false
    end
  end

  def fetch_file_versions(record)
    result = []


    if record['jsonmodel_type'] == 'archival_object'
      record['instances'].each do |instance|
        if instance['instance_type'] == 'digital_object'
          result += ASUtils.wrap(instance['digital_object']['_resolved']['file_versions'])
        end
      end
    elsif record['file_versions']
      result = ASUtils.wrap(record['file_versions'])
    elsif record['jsonmodel_type'] == 'file_version'
      result << record
    end

    result
  end
end