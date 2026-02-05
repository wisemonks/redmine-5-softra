module MailerPatch
  def self.included(base)
    base.class_eval do
      helper_method :textilizable
      
      def view_context_class
        @view_context_class ||= begin
          klass = super
          klass.send(:prepend, MailerHelperPatch)
          klass
        end
      end
    end
  end
end
