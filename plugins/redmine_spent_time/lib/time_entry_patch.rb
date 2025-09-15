module TimeEntryPatch
  extend ActiveSupport::Concern
  included do
    validate :spent_on_validation

    def spent_on_validation
      if if minimum_time(User.current) && spent_on < minimum_time(User.current)
        errors.add(:spent_on, :invalid)
      end
    end
  
    def prior_friday(date)
      days_to_subtract = (date.cwday + 2) % 7
      days_to_subtract = 7 if days_to_subtract.zero?
      date - days_to_subtract
    end
  
    def minimum_time(current_user)
      return nil unless Setting.allow_logging_time.eql?('1') || !current_user.admin
  
      if Time.current.monday?
        if Time.current.hour.to_i >= Setting.allow_logging_time_till.to_time.hour.to_i
          Date.current
        else
          prior_friday(Date.current)
        end
      elsif Time.current.hour.to_i >= Setting.allow_logging_time_till.to_time.hour.to_i
        Date.current
      else
        Date.yesterday
      end
    end
  end
end