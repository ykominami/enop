# frozen_string_literal: true

# require "arxutils"
require 'arxutils_sqlite3'
require_relative 'dbacrecord'
require_relative 'enop/version'
require_relative 'enop/enop'
require_relative 'enop/dbutil'
require_relative 'enop/cli'

# Evernote操作用モジュール
module Enop
  OUTPUT_DIR = 'output'
  # PSTORE_DIR = "pstore"
  PSTORE_DIR = 'pstore_2'
  PSTORE_KEY = :TOP
end
