require 'spec_helper'
require 'fake_ftp/commands/cdup'

describe FakeFtp::Command::Cdup, '#run' do
  let(:server) { double() }
  subject { FakeFtp::Command::Cdup.new(server) }

  it 'responds with 250' do
    expect(subject.run).to eql('250 OK!')
  end
end
