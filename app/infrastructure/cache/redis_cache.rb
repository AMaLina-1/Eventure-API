# frozen_string_literal: true

require 'redis'

module Eventure
  module Cache
    # Redis client utility
    class Client
      def initialize(config)
        @redis = Redis.new(url: config.REDISCLOUD_URL)
      end

      def keys
        @redis.keys
      end

      def wipe
        keys.each { |key| @redis.del(key) }
      end

      def get(key)
        @redis.get(key)
      end

      def set(key, value, exp: nil)
        if exp
          @redis.set(key, value, exp: ex)
        else
          @redis.set(key, value)
        end
      end

      def del(key)
        @redis.del(key)
      end

      def exists?(key)
        @redis.exists?(key)
      end
    end
  end
end
