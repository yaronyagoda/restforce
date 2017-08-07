module Restforce
  module Concerns
    module Streaming


      def on_disconnect(&block)
        @disconnect_block = block
      end
      # Public: Subscribe to a PushTopic
      #
      # channels - The name of the PushTopic channel(s) to subscribe to.
      # block    - A block to run when a new message is received.
      #
      # Returns a Faye::Subscription
      def subscribe(channels, &block)
        faye.subscribe Array(channels).map { |channel| "/topic/#{channel}" }, &block
      end

      # Public: Faye client to use for subscribing to PushTopics
      def faye
        unless options[:instance_url]
          raise 'Instance URL missing. Call .authenticate! first.'
        end

        url = "#{options[:instance_url]}/cometd/#{options[:api_version]}"

        @faye ||= Faye::Client.new(url).tap do |client|
          client.set_header 'Authorization', "OAuth #{options[:oauth_token]}"

          client.bind 'transport:down' do
            Restforce.log "[COMETD DOWN]"
            client.set_header 'Authorization', "OAuth #{authenticate!.access_token}"
          end

          client.bind 'transport:up' do
            Restforce.log "[COMETD UP]"
          end

          client.add_extension ReplayExtension.new(replay_handlers) if @disconnect_block.present?

        end
      end

      class OnDisconnectExtension
        def initialize(disconnect_block)
          @disconnect_block = disconnect_block
        end

        def incoming(message, callback)
          Restforce.log ("OnDisconnectExtension - recieved a message #{message}")
          if message['channel'] == "/meta/disconnect"
            Restforce.log ("OnDisconnectExtension - recieved a disconenct message #{message}")
            @disconnect_block.call
          end
          callback.call(message)
        end

        def outgoing(message, callback)
          callback.call(message)
        end
      end
    end
  end
end
