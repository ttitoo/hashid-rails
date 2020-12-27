# frozen_string_literal: true

require "hashid/rails/version"
require "hashid/rails/configuration"
require "hashids"
require "active_record"

module HashidRails 
  HASHID_TOKEN = 42

  def self.included(base)
    base.extend(ClassMethods)
  end

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

  def hashid
    self.class.encode_id(id)
  end

  def to_param
    self.class.hashid_configuration.override_to_param ? hashid : super
  end

  module ClassMethods
    def hashid_config(options = {})
      config = HashidRails.configuration.dup
      config.pepper = table_name
      options.each do |attr, value|
        config.public_send("#{attr}=", value)
      end
      @hashid_configuration = config
    end

    def hashid_configuration
      @hashid_configuration || hashid_config
    end

    def reset_hashid_config
      @hashid_configuration = nil
    end

    def relation
      super.tap { |r| r.extend ClassMethods }
    end

    def has_many(*args, &block)
      options = args.extract_options!
      options[:extend] = Array(options[:extend]).push(ClassMethods)
      super(*args, **options, &block)
    end

    def encode_id(ids)
      if ids.is_a?(Array)
        ids.map { |id| hashid_encode(id) }
      else
        hashid_encode(ids)
      end
    end

    # @param ids [String, Integer, Array<Integer, String>] id(s) to decode.
    # @param fallback [Boolean] indicates whether to return the passed in
    #   id(s) if unable to decode or if already decoded.
    def decode_id(ids, fallback: false)
      if ids.is_a?(Array)
        ids.map { |id| hashid_decode(id, fallback: fallback) }
      else
        hashid_decode(ids, fallback: fallback)
      end
    end

    def find(*ids)
      expects_array = ids.first.is_a?(Array)

      uniq_ids = ids.flatten.compact.uniq
      uniq_ids = uniq_ids.first unless expects_array || uniq_ids.size > 1

      if hashid_configuration.override_find
        super(decode_id(uniq_ids, fallback: true))
      else
        super
      end
    end

    def find_by_hashid(hashid)
      find_by(id: decode_id(hashid, fallback: false))
    end

    def find_by_hashid!(hashid)
      find_by!(id: decode_id(hashid, fallback: false))
    end

    private

    def hashids
      Hashids.new(*hashid_configuration.to_args)
    end

    def hashid_encode(id)
      return nil if id.nil?

      if hashid_configuration.sign_hashids
        hashids.encode(HASHID_TOKEN, id)
      else
        hashids.encode(id)
      end
    end

    def hashid_decode(id, fallback:)
      fallback_value = fallback ? id : nil
      decoded_hashid = hashids.decode(id.to_s)

      if hashid_configuration.sign_hashids
        valid_hashid?(decoded_hashid) ? decoded_hashid.last : fallback_value
      else
        decoded_hashid.first || fallback_value
      end
    rescue Hashids::InputError
      fallback_value
    end

    def valid_hashid?(decoded_hashid)
      decoded_hashid.size == 2 && decoded_hashid.first == HASHID_TOKEN
    end
  end
end
