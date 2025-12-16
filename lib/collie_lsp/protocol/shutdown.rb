# frozen_string_literal: true

module CollieLsp
  module Protocol
    # Handles shutdown and exit LSP messages
    module Shutdown
      module_function

      # Handle shutdown request
      # @param request [Hash] LSP request
      # @param writer [Object] Response writer
      def handle(request, writer)
        writer.write(
          id: request[:id],
          result: nil
        )
      end

      # Handle exit notification
      def handle_exit
        exit(0)
      end
    end
  end
end
