require "action_dispatch"
require "action_pack"

module SecureEscrow
  module Railtie
    module Routing
      def post *args, &block
        options = args.last.kind_of?(Hash) ? args.last : {}
        escrow = options.delete(:escrow)

        # This modifies the options hash that gets supered
        # up to the original post implementation
        mark_escrow!(options, &block) if escrow

        # This may rely on the options hash having been modified
        super(*args, &block)
      end

      private
      def mark_escrow! options, &block
        segment, endpoint = options.select do |k, v|
          k.kind_of?(String)
        end.first

        Rails.application.config.escrow.recognize_escrow segment

        # Mark the Rails routes as escrowed
        # so they can be recognized by the Middleware
        options[:defaults] ||= {}
        options[:defaults][:escrow] = true
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

ActionView::Base.send(:include, SecureEscrow::Railtie::ActionViewHelper)
ActionDispatch::Routing::Mapper.send(:include, SecureEscrow::Railtie::Routing)

