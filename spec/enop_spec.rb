# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Enop do
  # let( :token ) { ENV.fetch("EN_DEV_TOKEN", nil) }
  let(:token) { ENV.fetch('EN_DEV_TOKEN', nil) }
  let(:url) { ENV.fetch('EN_NOTESTORE_URL', nil) }
  let(:env) { ENV.fetch('ENV', 'production') }

  it 'has a version number' do
    expect(Enop::VERSION).not_to be_nil
  end

  it 'Enop get from local', cmd: :local do
    enop = TestSetup.setup(token, url, env)
    ret = enop.list_notebooks(from_backup: false)
    ex = enop.class.fetch_state('Exception')
    show_ex(ex)
    aggregate_failures '' do
      expect(ret).not_to be_nil
    end
  end

  it 'Enop get from remote', cmd: :remote do
    env ||= 'production'
    enop = TestSetup.setup(token, url, env)
    ret = enop.list_notebooks(from_backup: true)

    aggregate_failures '' do
      # expect( enop.class.fetch_state("Exception") ).to eq(nil)
      # p "ret.size=#{ret.size}"
      # expect(!ret.empty?).to be_truthy
      expect(ret).not_to be_nil
    end
    #    expect(ret).to eq(true)
  end
end
