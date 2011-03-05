require "spec_helper.rb"

describe FakeFtp::File do
  context 'attributes' do
    before :each do
      @file = FakeFtp::File.new
    end

    it "has a name attribute" do
      @file.name = "some name"
      @file.name.should == "some name"
    end

    it "has a bytes attribute" do
      @file.bytes = 87
      @file.bytes.should == 87
    end
  end

  context 'setup' do
    it "can be initialized with name and bytes" do
      file = FakeFtp::File.new('filename', 104)
      file.name.should == 'filename'
      file.bytes.should == 104
    end
  end
end
