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

        def data_with_legacy(packed)
          Rails.logger.info 'data_with_legacy'
          data_without_legacy( packed )
          Rails.logger.info @data.blank?
          Rails.logger.info self['data'].blank?
          if @data.blank? && !self['data'].blank?
            @data = Marshal.load(self['data'].unpack("m*").first) 
          end
          Rails.logger.info @data
          @data
        end
        alias_method_chain :data, :legacy

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
