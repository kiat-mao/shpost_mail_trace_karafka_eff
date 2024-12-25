class AirMail < ApplicationRecord
  belongs_to :post_unit, class_name: 'Unit', optional: true
  belongs_to :last_unit, class_name: 'Unit', optional: true
  
  enum direction: {import: 'import', export: 'export'}
  DIRECTION_NAME = { import: '进口', export: '妥投', returns: '出口'}

  enum status: {waiting: 'waiting', delivered: 'delivered', returns: 'returns', del: 'del'}
  STATUS_NAME = { waiting: '未妥投', delivered: '妥投', returns: '退回'}

  enum whereis: {in_transit: 'in_transit', delivery_part: 'delivery part'}
  WHEREIS_NAME = {in_transit: '在途中', delivery_part: '投递端'}


  IMPORT_VEHICLE_CODE = ['CF9025', 'CF9115']
  EXPORT_VECHICLE_CODE = ['CF9026', 'CF9116']

  AIR_OP_CODE = '911'

  # GUANGDONG_PROVINCE_NO = '440000'
  # SHANGHAI_PROVINCE_NO = '310000'

  PROVINCE_NO = ['310000', '440000']

  MAIL_NO_START = '1'

  # GUANGZHOU_AIRCENTER_CODE = '51000061'
  # AIR_OP_CODE = '389'

  # LAND_TRANSPORT = '3'
  

  JM_ORG_CODE = '20120015' #嘉民航空中心
  JM_OP_CODE ='954'

  # SHENZHEN_ORG_CODE = '51800100'

  DELIVERED_CODE = ['704', '748', '747']
  RETURNS_CODE = ["708", '711']
  DELETE_CODE = ["207"]

  DELIVERY_PART_CODE = ['306', '307', '702', '705']

  def self.refresh_traces! msg_hash
    create_air_mails! msg_hash

    update_air_mails_arrived_jm! msg_hash

    refresh_traces_air_mails_delivery! msg_hash
  end

  def self.create_air_mails! msg_hash
    air_mails_trace = msg_hash.reject{|x| ! x['opCode'].eql?(AIR_OP_CODE)}.reject{|x| ! x['vehicleCode'].in?(IMPORT_VEHICLE_CODE | EXPORT_VECHICLE_CODE)}.sort{|x,y| x["opTime"] <=> y["opTime"]}

    air_mails_trace.each do |trace|
      create_air_mail_by_trace! trace
    end
  end

  def self.create_air_mail_by_trace! trace
    mail_no = trace['traceNo']
    return if ! mail_no.start_with? MAIL_NO_START
    return if AirMail.exists?(mail_no: mail_no)
    
    flight_number = trace['vehicleCode']
    op_time = trace["opTime"].to_time

    direction = directions[:import] if flight_number.in? IMPORT_VEHICLE_CODE
    direction ||= directions[:export]if flight_number.in? EXPORT_VECHICLE_CODE
    
    air_mail = AirMail.new
    air_mail.mail_no = mail_no
    air_mail.flight_date = op_time
    air_mail.flight_number = flight_number
    air_mail.direction = direction
    air_mail.last_op_at = op_time
    air_mail.last_op_desc = trace["opDesc"]
    air_mail.last_unit_name = trace["opOrgName"]
    

    air_mail.status = statuses[:waiting]
    air_mail.whereis = whereis[:in_transit]

    pkp = PkpWaybillBase.where(waybill_no: mail_no).last
    if ! pkp.blank?
      return if ! sender_province_no.in? PROVINCE_NO
      return if ! receiver_province_no.in? PROVINCE_NO
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

      if ! pkp.post_org_no.blank?
        air_mail.post_unit_no = pkp.post_org_no
        air_mail.post_unit_name = pkp.post_org_name
        
        post_unit = Unit.where(no: pkp.post_org_no).last
        
        if ! post_unit.blank?
          air_mail.post_unit = post_unit
        end
      end

      # air_mail.posting_hour = pkp.biz_occur_date.hour

      
      air_mail.save!
    end
  end
  
  def self.update_air_mails_arrived_jm! msg_hash
    mails = msg_hash.reject{|x| ! x['opOrgCode'].eql?(JM_ORG_CODE)}.reject{|x| ! x['opCode'].eql?(JM_OP_CODE)}.sort{|x,y| x["opTime"] <=> y["opTime"]}

    mails.each do |x|
      mail_no = x['traceNo']
      op_time = x["opTime"].to_time

      next if ! AirMail.exists?(mail_no: mail_no)
      air_mail = AirMail.find_by mail_no: mail_no

      # next if AirMail.

      air_mail.arrive_jm_at = op_time
      air_mail.last_op_at = op_time
      air_mail.last_op_desc = x["opDesc"]
      air_mail.last_unit_name = x["opOrgName"]

      air_mail.save!
    end
  end

  def self.refresh_traces_air_mails_delivery! msg_hash
    air_mail_no = msg_hash.first["traceNo"]

    last_trace = AirMail.get_last_trace msg_hash

    air_mail = self.waiting.where("last_op_at < '#{last_trace['opTime']}'").or(AirMail.where(last_op_at:nil)).find_by(mail_no: air_mail_no)

    #only update not waiting air_mail to avoid repeating
    if ! air_mail.blank? && air_mail.waiting? 
      air_mail.refresh_trace! last_trace
      return true
    else
      return false
    end
  end

  def self.get_last_trace(traces)
    delivered_code = ['704', '748', '747']
    returns_code = ["708", '711']
    delete_code = ["207"]

    last_trace = traces.reject{|x| ! x['opCode'].in? delete_code}.last
    last_trace ||= traces.reject{|x| ! x['opCode'].in? returns_code}.last
    last_trace ||= traces.reject{|x| ! x['opCode'].in? delivered_code}.last
    last_trace ||= traces.last

    return last_trace
  end

  def refresh_trace! last_trace = nil
    self.refresh_trace last_trace

    self.save!
  end

  def refresh_trace last_trace
    # return if last_trace.blank?
    self.last_op_at = last_trace["opTime"]
    self.last_op_desc = last_trace["opDesc"]
    self.last_unit_name = last_trace["opOrgName"]
    self.last_unit_no = last_trace["opOrgCode"]
    self.last_unit = Unit.find_by no: last_trace["opOrgCode"]
    
    self.status = AirMail.get_status(last_trace["opCode"])

    self.whereis = self.waiting? ? AirMail.to_whereis(last_trace["opCode"]) : whereis[:delivery_part]
  end

  def self.to_whereis(code)
    if code.in? DELIVERY_PART_CODE
      whereis[:delivery_part]
    else
      whereis[:in_transit]
    end
  end

  def self.get_status(opt_code)
    status = AirMail::statuses[:del] if opt_code.in? DELETE_CODE
    status ||= AirMail::statuses[:returns] if opt_code.in? RETURNS_CODE
    status ||= AirMail::statuses[:delivered] if opt_code.in? DELIVERED_CODE
    status ||= AirMail::statuses[:waiting]

    return status
  end
end