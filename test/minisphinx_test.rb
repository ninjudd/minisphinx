require File.dirname(__FILE__) + '/test_helper'
require 'tmpdir'

class MinisphinxTest < Test::Unit::TestCase
  class CreateTables < ActiveRecord::Migration
    def self.up
      create_table :pets do |t|
        t.column :name, :string
        t.column :species, :string
        t.column :breed, :string
        t.column :color, :string
        t.column :gender, :string
        t.column :adopted, :boolean
      end
    end

    def self.down
      drop_table :pets
    end
  end

  class Pet < ActiveRecord::Base
    extend Minisphinx

    def self.initialize_sphinx
      sphinx_source :pets,
        :fetch_key   => 'public_id',
        :delta_field => 'CASE WHEN master_profile THEN now() ELSE updated_at END',
        :fields => [
          {:field => 'name',    :sortable => true},
          {:field => 'species', :sortable => true},
          {:field => 'breed',   :sortable => true},
          {:field => 'gender',  :sortable => true},
          {:field => 'adopted', :type => :boolean},
        ]

      Minisphinx::Index.config[:source ] = :profiles
      Minisphinx::Index.config[:delta  ] = true

      sphinx_index :full
    end
  end

  context 'with a db connection' do
    setup do
      CreateTables.verbose = false
      CreateTables.up
    end

    teardown do
      CreateTables.down
    end

    should "write config" do
      Pet.initialize_sphinx
      Dir.mktmpdir("minisphinx-test") do |path|
        Minisphinx.configure(:path => path)
        assert File.exists?("#{path}/sphinx.conf")
      end
    end
  end
end
