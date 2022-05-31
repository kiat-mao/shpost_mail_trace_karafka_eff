class InterfaceLog < ApplicationRecord
  # belongs_to :unit
  # belongs_to :business
  # belongs_to :parent, polymorphic: true
  STATUS = {success: 'success', failed: 'failed'}
  # STATUS_NAME = { success: '成功', failed: '失败' }

  # # def self.log(controller, action, unit, business, status, request_body, request_header, params, response_body, request_ip, business_code, parent)
  #   interface_log = InterfaceLog.find_by(controller_name: controller, action_name: action, unit: unit, business: business, status: 'failed', business_code: business_code) if (! status && ! business_code.blank?)
  #   if interface_log.blank?
  #     interface_log = InterfaceLog.create!(controller_name: controller, action_name: action, unit: unit, business: business, status: (status ? STATUS[:success] : STATUS[:failed]), request_body: request_body, params: params, response_body: response, request_ip: request_ip,business_code: business_code, parent: parent)
  #   else
  #     interface_log.update!(request_body: request_body, params: params, response_body: response, request_ip: request_ip, parent: parent)
  #   end
  # end
  def self.log(controller_name, action_name, status, *args)

    # interface_log = InterfaceLog.find_by(controller_name: controller, action_name: action, unit: unit, business: business, status: 'failed', business_code: business_code) if (! status && ! business_code.blank?)

    interface_log = new(controller_name: controller_name, action_name: action_name, status: status)

    if ! args.first.blank? && args.first.is_a?(Hash)
      args.first.each_key do |key|
        if interface_log.respond_to? "#{key}="
          interface_log.send "#{key}=", args.first[key.to_sym]
        end
      end
    end
    # binding.pry
    interface_log.save!
  end
end
