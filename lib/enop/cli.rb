# frozen_string_literal: true

require "arxutils_sqlite3"

module Enop
  # コマンドライン処理用クラス
  class Cli
    def self.show_token_url(config, token, url)
      puts config
      puts "token=#{token}"
      puts "url=#{url}"
    end

    def self.setup
      token = ENV.fetch("EN_DEV_TOKEN", nil)
      url = ENV.fetch("EN_NOTESTORE_URL", nil)
      env = ENV.fetch("ENV", nil)
      # env ||= "development"
      env ||= "production"

      hash = {
        "output_dir" => "output",
        "db_dir" => Arxutils_Sqlite3::Config::DB_DIR,
        "config_dir" => Arxutils_Sqlite3::Config::CONFIG_DIR,
        "env" => env,
        "dbconfig" => Arxutils_Sqlite3::Config::DBCONFIG_SQLITE3
      }

      [token, url, hash]
    end
  end
end
