require 'spec_helper'

shared_examples "pdf file" do
  let(:filesize) {File.size(filepath)}
  it "should response be ok" do expect(last_response).to be_ok end
  it "should content type be application/pdf" do expect(last_response.header['Content-Type']).to eq('application/pdf') end
  it "should content length be correct" do expect(last_response.header['Content-Length']).to eq(filesize.to_s) end

end

describe 'Files:' do
  before(:all) do
    RSpec.configure { |c| c.include RSpecMixin }
    @temp=configure_empty_sqlite
    SystematicReview.insert(:name=>'Test Review', :group_id=>1, :sr_administrator=>1)
    CanonicalDocument.insert(id:1, :title=>'Canonical Document 1', year:2018)
    login_admin
  end
  
  def check_gs
    !gs_available or ENV['TEST_TRAVIS'] or is_windows?
  end
  
  def filepath
    filename="2010_Kiritchenko_et_al_ExaCT_automatic_extraction_of_clinical_trial_characteristics_from_journal_publications.pdf"
    path=File.expand_path("#{File.dirname(__FILE__)}/../docs/guide_resources/#{filename}")
    #$log.info(path)
    path
  end


  context 'when upload a file using /review/files/add' do
    before(:context) do
      uploaded_file=Rack::Test::UploadedFile.new(filepath, "application/pdf", true)
      post '/review/files/add', systematic_review_id:sr_by_name_id('Test Review'), files:[uploaded_file]
    end
    let(:file) {IFile[1]}
    let(:app_helpers) {Class.new {extend Buhos::Helpers}}
    it "should response will be redirect" do $log.info(last_response.body); expect(last_response).to be_redirect end
    it "should create an file object" do expect(file).to be_truthy end
    it "should create an file object with correct mime type" do expect(file[:filetype]).to eq("application/pdf") end
    it "should create a file on correct directory" do
      path="#{app_helpers.dir_files}/#{file[:file_path]}"
      expect(File.exist? path).to be true
    end
    it "should create a file of correct size" do
      path="#{app_helpers.dir_files}/#{file[:file_path]}"
      expect(File.size(path)).to eq(File.size(filepath))
    end
  end

  context "when access ViewerJs" do
    it "should return correct html" do
      get '/ViewerJS/index.html'
      expect(last_response).to be_ok
      expect(last_response.body).to include("This file is the compiled version of the ViewerJS module")
    end
  end
  context "when access /ViewerJS/..file/:id/download format, response " do
    before(:context) do
      get '/ViewerJS/..file/1/download'
    end
    include_examples "pdf file"

  end
  context "when user downloads a file, response" do
    before(:context) do
      get '/file/1/download'
    end
    include_examples "pdf file"
  end

  context "when user downloads a file, response" do
    before(:context) do
      get '/file/1/view'
    end
    include_examples "pdf file"
    it {expect(last_response.header['Content-Disposition']).to include('inline') }
  end


  context "when user retrieves a page from a pdf as text, response" do
    before(:context) do
      get '/file/1/page/1/text'
    end
    it {expect(last_response).to be_ok }
    it {expect(last_response.header['Content-Type']).to include("text/html") }
    it {expect(last_response.body).to include("ExaCT")}
  end
  # Works, but is very slow
  context "when user retrieves a page from a pdf as image, response" do

    let(:gs_available) {check_executable_on_path('gs')}

    before(:context) do
      get '/file/1/page/17/image'
    end
    it {skip if check_gs;expect(last_response).to be_ok }
    it {skip if check_gs; expect(last_response.header['Content-Type']).to include("image/png") }
    it {skip if check_gs;expect(last_response.header['Content-Length'].to_i).to be >0}
  end

  context "when change attribute of a file" do
    before(:context) do
      put '/file/edit_field/filename', {pk:1, value:'exact.pdf'}
    end
    it {expect(last_response).to be_ok }
    it "should row on database be changed" do
      expect(IFile[1][:filename]).to eq('exact.pdf')
    end

  end

  context "when assign a file to a canonical document" do
    before(:context) do
      post '/file/assign_to_canonical',  file_id:1, cd_id:1
    end
    it "response should be ok " do expect(last_response).to be_ok end
    it "response should include a link to document" do expect(last_response.body).to include("/canonical_document/1") end
    it "relation should be included on database" do expect(FileCd[:file_id=>1, :canonical_document_id=>1]).to be_truthy end



  end


  context "when unassign a file to a canonical document" do
    before(:each) do
      post '/file/assign_to_canonical',  file_id:1, cd_id:1
    end

    it "by /file/assign_to_canonical should return a text " do
      post '/file/assign_to_canonical',  file_id:1, cd_id:''
      expect(last_response).to be_ok
      expect(last_response.body).to include I18n::t("file_handler.no_canonical_document")
      expect(FileCd[:file_id=>1, :canonical_document_id=>1]).to be_nil
    end
    it 'by /file/unassign_cd should delete object' do
      post '/file/unassign_cd', :file_id=>1, :cd_id=>1
      expect(last_response).to be_ok
      expect(FileCd[:file_id=>1, :canonical_document_id=>1]).to be_nil

    end



  end

  context "when hide a file from canonical document" do
    before(:each) do
      post '/file/assign_to_canonical',  file_id:1, cd_id:1
    end
    it "first should be visible" do
      expect(FileCd[:file_id=>1, :canonical_document_id=>1][:not_consider]).to be false
    end
    it "after unassign should be not visible" do
      post '/file/hide_cd', {  file_id:1, cd_id:1}
      expect(FileCd[:file_id=>1, :canonical_document_id=>1][:not_consider]).to be true
    end
  end

  context "when hide a file from canonical document" do
    before(:each) do
      post '/file/assign_to_canonical',  file_id:1, cd_id:1
      post '/file/hide_cd', {  file_id:1, cd_id:1}
    end
    it "first should be not visible" do
      expect(FileCd[:file_id=>1, :canonical_document_id=>1][:not_consider]).to be true
    end
    it "after show it should be not visible" do
      post '/file/show_cd', {  file_id:1, cd_id:1}
      expect(FileCd[:file_id=>1, :canonical_document_id=>1][:not_consider]).to be false
    end
  end



  context "when file is deleted" do
    before(:context) do
      post '/file/delete', {file_id:1}
    end
    it {expect(last_response).to be_ok }
    it "archivo object doesn't exists" do
      expect(IFile[1]).to be_nil
    end
  end

end