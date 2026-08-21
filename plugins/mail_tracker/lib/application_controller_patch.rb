module ApplicationControllerPatch
  def self.included(base)
    base.class_eval do
      before_action :sanitize_invalid_flash
    end
  end

  private

  def sanitize_invalid_flash
    return unless flash.present?

    invalid_keys = flash.to_hash.reject { |_, v| v.is_a?(String) }.keys
    invalid_keys.each { |key| flash.delete(key) }
  end
end
