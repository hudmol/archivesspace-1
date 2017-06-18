require 'spec_helper'
require 'stringio'

require_relative 'oai_response_checker'

describe 'OAI handler' do

  FIXTURES_DIR = File.join(File.dirname(__FILE__), "fixtures", "oai")

  def fake_job_monitor
    job_monitor = Object.new

    def job_monitor.method_missing(*)
      # Do nothing
    end

    job_monitor
  end

  before(:all) do
    @oai_repo_id = RequestContext.open do
      create(:repo, {:repo_code => "oai_test", :org_code => "oai", :name => "oai_test"}).id
    end

    test_subjects = ASUtils.json_parse(File.read(File.join(FIXTURES_DIR, 'subjects.json')))
    test_agents = ASUtils.json_parse(File.read(File.join(FIXTURES_DIR, 'agents.json')))

    test_resource_template = ASUtils.json_parse(File.read(File.join(FIXTURES_DIR, 'resource.json')))
    test_archival_object_template = ASUtils.json_parse(File.read(File.join(FIXTURES_DIR, 'archival_object.json')))

    # Create some test Resource records -- fully filled out with agents,
    # subjects and notes.
    test_record_count = 5

    test_resources = test_record_count.times.map do |i|
      resource = test_resource_template.clone
      resource['uri'] = "/repositories/2/resources/import_#{i}"
      resource['title'] = "Test resource #{i}"
      resource['id_0'] = "Resource OAI test #{i}"

      resource['ead_id'] = "ead_id_#{i}"
      resource['finding_aid_sponsor'] = "sponsor_#{i}"

      resource
    end

    # Create some Archival Object records -- same deal.
    test_archival_objects = test_record_count.times.map do |i|
      archival_object = test_archival_object_template.clone
      archival_object['uri'] = "/repositories/2/archival_objects/import_#{SecureRandom.hex}"
      archival_object['component_id'] = "ArchivalObject OAI test #{i}"
      archival_object['resource'] = {'ref' => test_resources.fetch(i).fetch('uri')}

      # Mark one of them with a different level for our set tests
      archival_object['level'] = ((i == 4) ? 'fonds' : 'file')

      archival_object
    end

    # Import the whole lot
    test_data = StringIO.new(ASUtils.to_json(test_subjects +
                                             test_agents +
                                             test_resources +
                                             test_archival_objects))

    RequestContext.open(:repo_id => @oai_repo_id) do
      created_records = as_test_user('admin') do
        StreamingImport.new(test_data, fake_job_monitor, false, false).process
      end

      @test_resource_record = created_records.fetch(test_resources[0]['uri'])
      @test_archival_object_record = created_records.fetch(test_archival_objects[0]['uri'])

      as_test_user('admin') do
        # Prepare some deletes
        5.times do
          ao = create(:json_archival_object)

          ArchivalObject[ao.id].delete
        end
      end
    end
  end

  around(:each) do |example|
    JSONModel.with_repository(@oai_repo_id) do
      RequestContext.open(:repo_id => @oai_repo_id) do
        example.run
      end
    end
  end

  before(:each) do
    # EAD export normally tries the search index first, but for the tests we'll
    # skip that since Solr isn't running.
    allow(Search).to receive(:records_for_uris) do |*|
      {'results' => []}
    end
  end

  def format_xml(s)
    Nokogiri::XML(s).to_xml(:indent => 2, :save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION)
  end

  XML_HEADER = "<!-- THIS FILE IS AUTOMATICALLY GENERATED - DO NOT EDIT.  To update it, just delete it and it will be regenerated from your test data. -->"

  def check_oai_request_against_fixture(fixture_name, params)
    fixture_file = File.join(FIXTURES_DIR, 'responses', fixture_name) + ".xml"

    result = ArchivesSpaceOaiProvider.new.process_request(params)

    # Setting the OAI_SPEC_RECORD will override our stored fixtures with
    # whatever we get back from the OAI.  Be sure to manually check the changes
    # to ensure that responses are what you were expecting.
    if !File.exist?(fixture_file)
      $stderr.puts("NOTE: Updating fixture #{fixture_file}")
      File.write(fixture_file, XML_HEADER + "\n" + format_xml(result))
    else
      OAIResponseChecker.compare(File.read(fixture_file), result)
    end
  end


  ###
  ### Tests start here
  ###

  describe "OAI protocol and mapping support" do

    RESOURCE_BASED_FORMATS = ['oai_ead']
    COMPONENT_BASED_FORMATS = ['oai_dc', 'oai_dcterms', 'oai_mods', 'oai_marc']

    it "responds to an OAI Identify request" do
      expect {
        check_oai_request_against_fixture('identify', :verb => 'Identify')
      }.to_not raise_error
    end

    it "responds to an OAI ListMetadataFormats request" do
      expect {
        check_oai_request_against_fixture('list_metadata_formats', :verb => 'ListMetadataFormats')
      }.to_not raise_error
    end

    it "responds to an OAI ListSets request" do
      expect {
        check_oai_request_against_fixture('list_sets', :verb => 'ListSets')
      }.to_not raise_error
    end


    RESOURCE_BASED_FORMATS.each do |prefix|
      it "responds to a GetRecord request for type #{prefix}, mapping appropriately" do
        expect {
          check_oai_request_against_fixture("getrecord_#{prefix}",
                                            :verb => 'GetRecord',
                                            :identifier => 'oai:archivesspace/' + @test_resource_record,
                                            :metadataPrefix => prefix)
        }.to_not raise_error
      end
    end

    COMPONENT_BASED_FORMATS.each do |prefix|
      it "responds to a GetRecord request for type #{prefix}, mapping appropriately" do
        expect {
          check_oai_request_against_fixture("getrecord_#{prefix}",
                                            :verb => 'GetRecord',
                                            :identifier => 'oai:archivesspace/' + @test_archival_object_record,
                                            :metadataPrefix => prefix)
        }.to_not raise_error
      end
    end
  end

  describe "ListIdentifiers" do

    def list_identifiers(prefix)
      params = {
        :verb => 'ListIdentifiers',
        :metadataPrefix => prefix,
      }

      result = ArchivesSpaceOaiProvider.new.process_request(params)

      doc = Nokogiri::XML(result)
      doc.remove_namespaces!

      doc.xpath("//identifier").map {|elt| elt.text}
    end

    RESOURCE_BASED_FORMATS.each do |prefix|
      it "responds to a ListIdentifiers request for type #{prefix}" do
        list_identifiers(prefix).all? {|identifier| identifier =~ %r{/resources/}}
      end
    end

    COMPONENT_BASED_FORMATS.each do |prefix|
      it "responds to a ListIdentifiers request for type #{prefix}" do
        list_identifiers(prefix).all? {|identifier| identifier =~ %r{/archival_objects/}}
      end
    end

  end

  describe "ListRecords" do

    let (:page_size) { 2 }

    let (:oai_repo) {
      oai_repo = ArchivesSpaceOAIRepository.new

      # Drop our page size to ensure we get a resumption token
      smaller_pages = ArchivesSpaceOAIRepository::FormatOptions.new([ArchivalObject], page_size)

      allow(oai_repo).to receive(:options_for_type)
                           .with('oai_dc')
                           .and_return(smaller_pages)

      oai_repo
    }

    it "supports an unqualified ListRecords request" do
      response = oai_repo.find(:all, {:metadata_prefix => "oai_dc"})
      response.records.length.should eq(page_size)
    end

    it "supports resumption tokens" do
      page1_response = oai_repo.find(:all, {:metadata_prefix => "oai_dc"})
      page1_uris = page1_response.records.map(&:jsonmodel_record).map(&:uri)

      page1_response.token.should_not be_nil

      page2_response = oai_repo.find(:all, {:resumption_token => page1_response.token.serialize})
      page2_uris = page2_response.records.map(&:jsonmodel_record).map(&:uri)

      # We got some different URIs on the next page
      (page2_uris + page1_uris).length.should eq(page1_uris.length + page2_uris.length)
    end

    it "supports date ranges when listing records" do
      start_time = Time.parse('1975-01-01 00:00:00 UTC')
      end_time = Time.parse('1976-01-01 00:00:00 UTC')

      margin = 86400
      record_count = 2

      # Backdate some of our AOs to fall within our timeframe of interest.
      #
      # Note that we do a simple UPDATE here to avoid having our Sequel model
      # save hook from updating the system_mtime to Time.now.
      #
      ao_ids = ArchivalObject.filter(:repo_id => @oai_repo_id).order(:id).all.take(record_count).map(&:id)
      ArchivalObject.filter(:id => ao_ids).update(:system_mtime => (start_time + margin))

      response = oai_repo.find(:all, {:metadata_prefix => "oai_dc",
                                      :from => start_time,
                                      :until => end_time})

      response.records.length.should eq(record_count)
    end

    it "lists deletes" do
      token = nil
      loop do
        opts = {:metadata_prefix => "oai_dc"}

        if token
          opts[:resumption_token] = token
        end

        response = oai_repo.find(:all, opts)

        if response.is_a?(Array)
          # Our final page of results--which should be entirely deletes
          response.all?(&:deleted?).should be(true)

          break
        elsif response.token
          # Next page!
          token = response.token.serialize
        else
          # Shouldn't have happened...
          fail "no deletes found"
          break
        end
      end
    end

    it "supports OAI sets based on levels" do
      response = oai_repo.find(:all, {:metadata_prefix => "oai_dc", :set => 'fonds'})
      response.records.length.should be > 0

      response.records.map(&:jsonmodel_record).map(&:level).uniq.should eq(['fonds'])
    end


    it "supports OAI sets based on sponsors" do
      allow(AppConfig).to receive(:has_key?).with(any_args).and_call_original
      allow(AppConfig).to receive(:has_key?).with(:oai_sets).and_return(true)

      allow(AppConfig).to receive(:[]).with(any_args).and_call_original
      allow(AppConfig).to receive(:[]).with(:oai_sets)
                            .and_return('sponsor_0' => {
                                          :sponsors => ['sponsor_0']
                                        })

      response = oai_repo.find(:all, {:metadata_prefix => "oai_dc", :set => 'sponsor_0'})

      response.records.all? {|record| record.jsonmodel_record.resource['ref'] == @test_resource_record}
        .should be(true)
    end

    it "supports OAI sets based on repositories" do
      allow(AppConfig).to receive(:has_key?).with(any_args).and_call_original
      allow(AppConfig).to receive(:has_key?).with(:oai_sets).and_return(true)

      allow(AppConfig).to receive(:[]).with(any_args).and_call_original
      allow(AppConfig).to receive(:[]).with(:oai_sets)
                            .and_return('by_repo' => {
                                          :repo_codes => ['oai_test']
                                        })

      response = oai_repo.find(:all, {:metadata_prefix => "oai_dc", :set => 'by_repo'})
      response.records.all? {|record| record.sequel_record.repo_id == @oai_repo_id}
        .should be(true)
    end

    it "doesn't reveal published or suppressed records" do
      unpublished = create(:json_archival_object, :publish => false, :resource => {:ref => @test_resource_record})
      suppressed = create(:json_archival_object, :publish => true, :resource => {:ref => @test_resource_record})
      ArchivalObject[suppressed.id].set_suppressed(true)

      token = nil
      loop do
        opts = {:metadata_prefix => "oai_dc"}

        if token
          opts[:resumption_token] = token
        end

        response = oai_repo.find(:all, opts)

        records = []

        if response.respond_to?(:token)
          # A partial response
          token = response.token.serialize
          records = response.records
        elsif response.is_a?(Array)
          records = response
          token = nil
        else
          # Shouldn't have happened...
          fail "unexpected result"
          break
        end

        prohibited_uris = [unpublished.uri, suppressed.uri]

        records.each do |record|
          if record.is_a?(ArchivesSpaceOAIRecord) && prohibited_uris.include?(record.jsonmodel_record.uri)
            fail "URI #{record.jsonmodel_record.uri} is unpublished/suppressed and should not be shown in OAI results"
          end
        end

        break if token.nil?
      end
    end

  end

end
