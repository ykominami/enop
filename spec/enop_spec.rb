require 'spec_helper'

describe Enop do
  it 'has a version number' do
    expect(Enop::VERSION).not_to be nil
  end

  it 'does something useful' do
    config = nil
    token = ENV.fetch("EVERNOTE_DEVELOPER_TOKEN", nil)
    url = ENV.fetch("EVERNOTE_NOTESTORE_URL", nil)

    env = ENV.fetch("ENV", nil)
    #env ||= "development"
    env ||= "production"

    opts = { db_dir: Arxutils_Sqlite3::Config::DB_DIR }
    banner = "Usage: bundle exec ruby exe/enop token url"

    opts["dbconfig"] = Arxutils_Sqlite3::Config::DBCONFIG_SQLITE3 unless opts["dbconfig"]
    hs = {
      "output_dir" => "output",
      "db_dir" => Arxutils_Sqlite3::Config::DB_DIR,
      "config_dir" => Arxutils_Sqlite3::Config::CONFIG_DIR,
      "env" => env,
      "dbconfig" => opts["dbconfig"],
    }
    enop = Enop::Enop.new(
                          token,
                          hs,
                          url,
                          )
    enop.connect
    #p "================="
    ret = enop.list_notebooks(false)

    expect(ret).to_not be(nil)
#    expect(ret).to eq(true)
  end
end
