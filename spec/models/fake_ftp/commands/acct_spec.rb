require 'spec_helper'
require 'fake_ftp/commands/acct'

describe FakeFtp::Command::Acct, '#run' do
  let(:server) { double() }
  subject { FakeFtp::Command::Acct.new(server) }

  it 'responds with 230' do
    expect(subject.run).to eql('230 WHATEVER!')
  end
end
