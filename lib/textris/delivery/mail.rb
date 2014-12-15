module Textris
  module Delivery
    class Mail < Textris::Delivery::Base
      class Mailer < ActionMailer::Base
        def notify(from, to, subject, body)
          mail :from => from, :to => to, :subject => subject, :body => body
        end
      end

      class << self
        private

        def send_message(to, message)
          template_vars = { :to_phone => to }

          from    = apply_template from_template,    message, template_vars
          to      = apply_template to_template,      message, template_vars
          subject = apply_template subject_template, message, template_vars
          body    = apply_template body_template,    message, template_vars

          ::Textris::Delivery::Mail::Mailer.notify(
            from, to, subject, body).deliver
        end

        def from_template
          Rails.application.config.try(:textris_mail_from_template) ||
            "%{from_name:d}-%{from_phone}@%{env:d}.%{app:d}.com"
        end

        def to_template
          Rails.application.config.try(:textris_mail_to_template) ||
            "%{app:d}-%{env:d}-%{to_phone}-texts@mailinator.com"
        end

        def subject_template
          Rails.application.config.try(:textris_mail_subject_template) ||
            "%{texter:dh} texter: %{action:h}"
        end

        def body_template
          Rails.application.config.try(:textris_mail_body_template) ||
            "%{content}"
        end

        def apply_template(template, message, variables)
          template.gsub(/\%\{[a-z_:]+\}/) do |match|
            directive = match.gsub(/[%{}]/, '')
            key       = directive.split(':').first
            modifiers = directive.split(':')[1] || ''

            content = get_template_interpolation(key, message, variables)
            content = apply_template_modifiers(content, modifiers.chars)
            content = 'unknown' unless content.present?

            content
          end
        end

        def get_template_interpolation(key, message, variables)
          content = case key
          when 'app'
            get_rails_application_name
          when 'env'
            get_rails_env_name
          when 'texter'
            get_message_texter_name(message)
          when 'action', 'from_name', 'from_phone', 'content'
            message.send(key)
          else
            variables[key.to_sym]
          end.to_s.strip
        end

        def get_rails_application_name
          Rails.application.class.parent_name
        end

        def get_rails_env_name
          Rails.env
        end

        def get_message_texter_name(message)
          message.texter.to_s.split('::').last.to_s.sub(/Texter$/, '')
        end

        def apply_template_modifiers(content, modifiers)
          modifiers.each do |modifier|
            case modifier
            when 'd'
              content = content.underscore.dasherize
            when 'h'
              content = content.humanize.gsub(/[-_]/, ' ')
            when 'p'
              content = Phony.format(content) rescue content
            end
          end

          content
        end
      end
    end
  end
end
