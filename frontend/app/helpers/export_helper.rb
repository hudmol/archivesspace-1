module ExportHelper

  def csv_response(request_uri, params = {} )
        self.response.headers["Content-Type"] = "text/csv"
        self.response.headers["Content-Disposition"] = "attachment; filename=#{Time.now.to_i}.csv"
        self.response.headers['Last-Modified'] = Time.now.ctime.to_s

        # Preserve filters
        filters = AdvancedQueryBuilder.new

        # The staff interface shouldn't show records that were only created for the
        # Public User Interface.
        filters.and('types', 'pui_only', 'text', literal = true, negated = true)

        Array(params['filter_term[]']).each do |json_filter|
          filter = ASUtils.json_parse(json_filter)
          filters.and(filter.keys[0], filter.values[0])
        end

        params['filter'] = filters.build.to_json

        params["dt"] = "csv"

        self.response_body = Enumerator.new do |y|
          xml_response(request_uri, params) do |chunk, percent|
            y << chunk if !chunk.blank?
          end
        end
  end

  def xml_response(request_uri, params = {})

    JSONModel::HTTP::stream(request_uri, params) do |res|
      size, total = 0, res.header['Content-Length'].to_i
      res.read_body do |chunk|
        size += chunk.size
        percent = total > 0 ? ((size * 100) / total) : 0
        yield chunk, percent
      end
    end

  end


end
