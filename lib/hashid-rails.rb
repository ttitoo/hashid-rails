# frozen_string_literal: true

require "hashid/rails/version"
require "hashid/rails/configuration"
require "hashids"
require "active_record"

module HashidRails 
  extend Hashid::Rails

  # Get configuration or load defaults
  def self.configuration
    @configuration ||= Hashid::Rails::Configuration.new
  end

  def self.configure
    yield(configuration)
  end

  # Reset gem configuration to defaults
  def self.reset
    @configuration = Hashid::Rails::Configuration.new
  end
end
