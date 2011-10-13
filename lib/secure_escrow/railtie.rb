require "action_dispatch"
require "action_pack"

module SecureEscrow
  module Railtie
    module Routing
      def escrow options, &block
        defaults = options[:defaults] || {}
        defaults[:escrow] = true
        post options.merge(defaults), &block
      end
    end

    module ActionViewHelper
      DATA_ESCROW = 'data-escrow'

      def escrow_form_for record, options = {}, &proc
        form_for record, escrow_options(options), &proc
      end

      def escrow_form_tag url_for_options = {}, options = {}, &block
        form_tag url_for_options, escrow_options(options), &block
      end

      private
      def escrow_options options
        html_options = options[:html] || {}
        options.merge(html: html_options.merge(DATA_ESCROW => true))
      end
    end
  end
end

