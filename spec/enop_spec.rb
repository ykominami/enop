require 'spec_helper'

RSpec.describe Enop do
  let( :token ) { ENV.fetch("EVERNOTE_DEVELOPER_TOKEN", nil) }
  let( :url ) { ENV.fetch("EVERNOTE_NOTESTORE_URL", nil) }
  let( :env ) { ENV.fetch("ENV", nil) }

  it 'has a version number' do
    expect(Enop::VERSION).not_to be nil
  end

  it 'Enop get from local' , cmd: :local  do
    remote = false
    enop = TestSetup.setup(token, url, env, false)
    ret = enop.list_notebooks(remote)

    expect(ret).to_not be(nil)
#    expect(ret).to eq(true)
  end

  it 'Enop get from remote' , cmd: :remote do
    remote = true
    enop = TestSetup.setup(token, url, env, true)
    ret = enop.list_notebooks(remote)

    expect(ret).to_not be(nil)
#    expect(ret).to eq(true)
  end
end
