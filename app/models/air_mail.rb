class AirMail < ApplicationRecord
  enum direction: {import: 'import', export: 'export'}
  IMPORT_VEHICLE_CODE = ['CF9025', 'CF9115']
  EXPORT_VECHICLE_CODE = ['CF9026', 'CF9116']

  AIR_OP_CODE = '911'

  # GUANGDONG_PROVINCE_NO = '440000'
  # SHANGHAI_PROVINCE_NO = '310000'

  # GUANGZHOU_AIRCENTER_CODE = '51000061'
  # AIR_OP_CODE = '389'

  # LAND_TRANSPORT = '3'
  

  JM_ORG_CODE = '20120015' #嘉民航空中心
  JM_OP_CODE ='954'

  # SHENZHEN_ORG_CODE = '51800100'

  def self.refresh_traces! msg_hash
    create_air_mails! msg_hash

    update_air_mails_arrived_jm! msg_hash
  end

  def self.update_air_mails_arrived_jm! msg_hash
    mails = msg_hash.reject{|x| ! x['opOrgCode'].eql?(JM_ORG_CODE)}.reject{|x| ! x['opCode'].eql?(JM_OP_CODE)}.sort{|x,y| x["opTime"] <=> y["opTime"]}

    mails.each do |x|
      mail_no = x['traceNo']
      op_time = x["opTime"].to_time

      next if ! AirMail.exists?(mail_no: mail_no)
      air_mail = AirMail.find_by mail_no: mail_no

      next if AirMail.

      air_mail.arrive_jm_at = op_time
      air_mail.last_op_at = op_time
      air_mail.last_op_desc = x["opDesc"]
      air_mail.last_unit_name = x["opOrgName"]

      air_mail.save!
    end
  end

  def self.create_air_mails! msg_hash
    air_mails_trace = msg_hash.reject{|x| ! x['opCode'].eql?(AIR_OP_CODE)}.reject{|x| ! x['vehicleCode'].in?(IMPORT_VEHICLE_CODE | EXPORT_VECHICLE_CODE)}.sort{|x,y| x["opTime"] <=> y["opTime"]}

    air_mails_trace.each do |trace|
      create_air_mail_by_trace! trace
    end
  end

  def self.create_air_mail_by_trace! trace
      mail_no = trace['traceNo']

      return if AirMail.exists?(mail_no: mail_no)
      
      flight_number = trace['vehicleCode']
      op_time = trace["opTime"].to_time

      direction = "import" if flight_number.in? IMPORT_VEHICLE_CODE
      direction ||= "export" if flight_number.in? EXPORT_VECHICLE_CODE
      
      air_mail = AirMail.new
      air_mail.mail_no = mail_no
      air_mail.flight_date = op_time
      air_mail.flight_number = flight_number
      air_mail.direction = direction
      air_mail.last_op_at = op_time
      air_mail.last_op_desc = x["opDesc"]
      air_mail.last_unit_name = x["opOrgName"]

      pkp = PkpWaybillBase.where(waybill_no: mail_no).last
      if ! pkp.blank?
        air_mail.sender_province_name = pkp.sender_province_name
        air_mail.sender_city_name = pkp.sender_city_name
        air_mail.sender_county_name = pkp.sender_county_name
        air_mail.real_weight = pkp.real_weight
        air_mail.fee_weight = pkp.fee_weight
        air_mail.order_weight = pkp.order_weight
        air_mail.postage_paid = pkp.postage_paid
        air_mail.postage_total = pkp.postage_total
        air_mail.posting_date = pkp.biz_occur_date
        air_mail.transfer_type = pkp.transfer_type

        if ! pkp_waybill_base.post_org_no.blank?
          post_unit = Unit.where(no: pkp_waybill_base.post_org_no).last
          air_mail.post_unit_no = pkp_waybill_base.post_org_no
          if ! post_unit.blank?
            air_mail.post_unit = post_unit
          end
        end

        # air_mail.posting_hour = pkp_waybill_base.biz_occur_date.hour

        
        air_mail.save!
      end
    end
  end

end