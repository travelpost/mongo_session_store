require "mongo_session_store/mongo_store_base"

module ActionDispatch
  module Session
    class MongoidStore < MongoStoreBase
      class Session
        include Mongoid::Document
        include Mongoid::Timestamps

        attr_writer :data

        store_in :collection => MongoSessionStore.collection_name

        field :_data, :type => BSON::Binary, :default => -> { pack({}) }

        def self.pack(data)
          BSON::Binary.new(Marshal.dump(data), :generic)
        end

        def data
          @data ||= unpack(_data)
        end

        # Begin monkeypatch
        # After 18mo no more Rails3.2 sessions should be around (trimmed) and we can remove this monkeypatch
        def data_with_legacy
          data_without_legacy
          if @data.blank? && !self['data'].blank?
            Rails.logger.info "Reading Rails 3.2 session"
            @data = Marshal.load(self['data'].unpack("m*").first) 
            Rails.logger.info "Rails 3.2 session data: #{@data}"
          elsif !@data.blank?
            Rails.logger.info "Rails 4 session data: #{@data}"
          end
          @data
        end
        alias_method_chain :data, :legacy
        # End monkeypatch

        def reload
          @data = nil
          super
        end

        private

        before_save do
          self._data = pack(data)
        end

        def pack(data)
          self.class.pack(data)
        end

        def unpack(packed)
          return unless packed
          if packed.respond_to? :data
            Marshal.load(packed.data)
          else
            Marshal.load(packed.to_s)
          end
        end
      end
    end
  end
end

MongoidStore = ActionDispatch::Session::MongoidStore
