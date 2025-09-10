class AirMail < ApplicationRecord
  belongs_to :post_unit, class_name: 'Unit', optional: true
  belongs_to :last_unit, class_name: 'Unit', optional: true
  
  enum direction: {import: 'import', export: 'export'}
  DIRECTION_NAME = { import: '进口', export: '出口'}

  enum status: {waiting: 'waiting', delivered: 'delivered', returns: 'returns', del: 'del'}
  STATUS_NAME = { waiting: '未妥投', delivered: '妥投', returns: '退回'}

  enum whereis: {arrive_shanghai: 'arrive_shanghai', arrive_jm: 'arrive_jm', leave_jm: 'leave_jm', arrive_center: 'arrive_center', leave_center: 'leave_center', arrive_sub: 'arrive_sub', delivery_part: 'delivery_part'}
  WHEREIS_NAME = {in_transit: '在途中', delivery_part: '投递端'}

  IMPORT_VEHICLE_CODE = ['CF9025', 'CF9115']
  EXPORT_VECHICLE_CODE = ['CF9026', 'CF9116']

  FLIGHT_LAND_CODE = ['912']

  GUANGDONG_PROVINCE_NO = '440000'
  SHANGHAI_PROVINCE_NO = '310000'

  PROVINCE_NO = [GUANGDONG_PROVINCE_NO, SHANGHAI_PROVINCE_NO]

  MAIL_NO_START = '1'

  # GUANGZHOU_AIRCENTER_CODE = '51000061'
  # AIR_OP_CODE = '389'

  # LAND_TRANSPORT = '3'
  

  JM_ORG_CODE = '20120015' #嘉民航空中心
  ARRIVE_TRANSFER_OP_CODE = ['954']
  # ARRIVE_JM_AT_COLUMN = 'arrive_jm_at'
  # IS_ARRIVE_JM_COLUMN = 'is_arrive_jm'
  LEAVE_TRANSFER_OP_CODE = ['389', '989']
  # LEAVE_JM_AT_COLUMN = 'arrive_jm_at'
  # IS_LEAVE_JM_COLUMN = 'is_arrive_jm'

  TP_ORG_CODE = '20000414' #桃浦航空中心
  WG_ORG_CODE = '20000061' #桃浦航空中心
  # ARRIVE_CENTER_OP_CODE ='954'
  # ARRIVE_CENTER_AT_COLUMN = 'arrive_center_at'
  # IS_ARRIVE_CENTER_COLUMN = 'is_arrive_center'
  # LEAVE_CENTER_OP_CODE = ['389', '989']
  # LEAVE_CENTER_AT_COLUMN = 'leave_center_at'
  # IS_LEAVE_CENTER_COLUMN = 'is_leave_center'
  # CENTER_COLUMN = 'transfer_center_unit_no'

  ARRIVE_SUB_OP_CODE = '306'
  IN_DELIVERY_OP_CODE = '702'

  # SHENZHEN_ORG_CODE = '51800100'

  DELIVERED_CODE = ['704', '748', '747']
  RETURNS_CODE = ["708", '711']
  DELETE_CODE = ["207"]

  def update_by_jdpt_traces!
    mail_trace = MailTrace.find_by(mail_no: self.mail_no)
    if ! mail_trace.blank?
      jdpt_traces = mail_trace.jdpt_traces
      AirMail.refresh_transfer_air_mails! jdpt_traces
      AirMail.refresh_in_delivery_air_mails! jdpt_traces
      AirMail.refresh_delivered_air_mails! jdpt_traces
    end
  end

  def self.refresh_traces! msg_hash
    create_air_mails! msg_hash

    refresh_transfer_air_mails! msg_hash

    refresh_in_delivery_air_mails! msg_hash

    refresh_delivered_air_mails! msg_hash
  end

  def self.create_air_mails! msg_hash
    air_mails_trace = msg_hash.reject{|x| ! x['opCode'].in?(FLIGHT_LAND_CODE)}
    
    #update flight_number to pkp_waybill_bases
    air_mails_trace.each do |trace|
      flight_number = trace['vehicleCode']
      mail_no = trace['traceNo']
      pkp_waybill_base = PkpWaybillBase.find_by(waybill_no: mail_no)
      pkp_waybill_base.update!(flight_number: flight_number) if pkp_waybill_base
    end

    air_mails_trace = air_mails_trace.reject{|x| ! x['vehicleCode'].in?(IMPORT_VEHICLE_CODE | EXPORT_VECHICLE_CODE)}.sort{|x,y| x["opTime"] <=> y["opTime"]}

    air_mails_trace.each do |trace|
      air_mail = create_air_mail_by_trace! trace

      air_mail.update_by_jdpt_traces! if ! air_mail.blank?
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
      if direction.eql?(directions[:import])
        if pkp.sender_province_no.eql?(SHANGHAI_PROVINCE_NO) || ! pkp.receiver_province_no.eql?(SHANGHAI_PROVINCE_NO)
          return
        end
      end

      if direction.eql?(directions[:export])
        if pkp.sender_province_no.eql?(GUANGDONG_PROVINCE_NO) || ! pkp.receiver_province_no.eql?(GUANGDONG_PROVINCE_NO)
          return
        end
      end
      # return if ! sender_province_no.in? PROVINCE_NO
      # return if ! receiver_province_no.in? PROVINCE_NO
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
      return air_mail
    end
  end

  def self.refresh_transfer_air_mails! msg_hash
    self.refresh_jm_air_mails! msg_hash
    self.refresh_center_air_mails! msg_hash
  end

  def self.refresh_jm_air_mails! msg_hash
    mails = msg_hash.reject{|x| ! x['opOrgCode'].eql?(JM_ORG_CODE) || ! x['opCode'].in?(ARRIVE_TRANSFER_OP_CODE | LEAVE_TRANSFER_OP_CODE)}.sort{|x,y| x["opTime"] <=> y["opTime"]}

    mails.each do |x|
      mail_no = x['traceNo']
      op_code = x["opCode"]
      op_time = x["opTime"].to_time

      next if ! AirMail.exists?(mail_no: mail_no, direction: directions[:import])
      air_mail = AirMail.find_by mail_no: mail_no

      next if op_code.in?(ARRIVE_TRANSFER_OP_CODE) && air_mail.is_arrive_jm && ! air_mail.arrive_jm_at.nil? && (op_time > air_mail.arrive_jm_at)
      next if op_code.in?(LEAVE_TRANSFER_OP_CODE) && air_mail.is_leave_jm && ! air_mail.leave_jm_at.nil? && (op_time > air_mail.leave_jm_at)

      if op_code.in?(ARRIVE_TRANSFER_OP_CODE)
        air_mail.is_arrive_jm = true
        air_mail.arrive_jm_at = op_time
      else
        air_mail.is_leave_jm = true
        air_mail.is_arrive_jm = true
        air_mail.leave_jm_at = op_time
      end

      air_mail.set_last_trace x

      air_mail.save!
    end
  end

  def self.refresh_center_air_mails! msg_hash
    mails = msg_hash.reject{|x| ! x['opOrgCode'].in?([TP_ORG_CODE, WG_ORG_CODE]) || ! x['opCode'].in?((ARRIVE_TRANSFER_OP_CODE | LEAVE_TRANSFER_OP_CODE))}.sort{|x,y| x["opTime"] <=> y["opTime"]}

    mails.each do |x|
      mail_no = x['traceNo']
      op_code = x["opCode"]
      op_time = x["opTime"].to_time
      unit_no = x["opOrgCode"]
      

      next if ! AirMail.exists?(mail_no: mail_no, direction: directions[:import])
      air_mail = AirMail.find_by mail_no: mail_no

      next if op_code.in?(ARRIVE_TRANSFER_OP_CODE) && air_mail.is_arrive_center && ! air_mail.arrive_center_at.nil? && (op_time > air_mail.arrive_center_at)
      next if op_code.in?(LEAVE_TRANSFER_OP_CODE) && air_mail.is_leave_center && ! air_mail.leave_center_at.nil? && (op_time > air_mail.leave_center_at)


      if op_code.in?(ARRIVE_TRANSFER_OP_CODE)
        air_mail.is_arrive_center = true
        air_mail.arrive_center_at = op_time
        # air_mail.is_leave_jm = true #春节后来验证是否存在到达离开处理中心，但完全没有嘉民信息的件
        air_mail.transfer_center_unit_no = unit_no
      else
        air_mail.is_leave_center = true
        air_mail.leave_center_at = op_time
        air_mail.is_arrive_center = true
        if op_time.to_date.eql?(air_mail.flight_date.to_date) && op_time.hour < 15
          air_mail.is_leave_center_in_time = true
        end
      end

      air_mail.set_last_trace x

      air_mail.save!
    end
  end

  # def self.refresh_transfer_air_mails! msg_hash, org_code, op_code, at_column, is_column, org_column = nil
  #   #JM
  #   mails = msg_hash.reject{|x| ! x['opOrgCode'].eql?(org_code) || ! x['opCode'].eql?(op_code)}.sort{|x,y| x["opTime"] <=> y["opTime"]}

  #   mails.each do |x|
  #     mail_no = x['traceNo']
  #     op_time = x["opTime"].to_time

  #     next if ! AirMail.exists?(mail_no: mail_no)
  #     air_mail = AirMail.find_by mail_no: mail_no

  #     return if air_mail.send("#{is_column}.eql?", true)

  #     air_mail.send("#{at_column}=", op_time)
  #     air_mail.send("#{is_column}=", true)

  #     if ! org_column.blank?
  #       air_mail.send("#{org_column}=", org_code)
  #     end

  #     if air_mail.last_op_at < op_time
  #       air_mail.last_op_at = op_time
  #       air_mail.last_op_desc = x["opDesc"]
  #       air_mail.last_unit_name = x["opOrgName"]
  #     end

  #     air_mail.save!
  #   end
  # end

  def self.refresh_in_delivery_air_mails! msg_hash
    mails = msg_hash.reject{|x| ! x['opCode'].in?([ARRIVE_SUB_OP_CODE, IN_DELIVERY_OP_CODE])}.sort{|x,y| x["opTime"] <=> y["opTime"]}
    mails.each do |x|
      mail_no = x['traceNo']
      op_code = x["opCode"]
      op_time = x["opTime"].to_time

      next if ! AirMail.exists?(mail_no: mail_no, direction: directions[:import])
      air_mail = AirMail.find_by mail_no: mail_no

      next if op_code.eql?(ARRIVE_SUB_OP_CODE) && air_mail.is_arrive_sub && ! air_mail.arrive_sub_at.nil? && (op_time > air_mail.arrive_sub_at)
      next if op_code.eql?(IN_DELIVERY_OP_CODE) && air_mail.is_in_delivery && ! air_mail.in_delivery_at.nil? && (op_time > air_mail.in_delivery_at)

      if op_code.eql?(ARRIVE_SUB_OP_CODE)
        air_mail.is_arrive_sub = true
        air_mail.arrive_sub_at = op_time
      else
        air_mail.is_arrive_sub = true
        air_mail.is_in_delivery = true
        air_mail.in_delivery_at = op_time
      end

      air_mail.set_last_trace x

      air_mail.save!
    end
  end

  def self.refresh_delivered_air_mails! msg_hash
    mails = AirMail.get_last_trace msg_hash

    mails.each do |x|
      mail_no = x['traceNo']
      op_code = x["opCode"]
      op_time = x["opTime"].to_time

      next if ! AirMail.exists?(mail_no: mail_no, direction: directions[:import], status: statuses[:waiting])
      air_mail = AirMail.find_by mail_no: mail_no

      air_mail.status = AirMail.get_status(x["opCode"])
      
      air_mail.is_arrive_sub = true
      air_mail.is_in_delivery = true      

      if air_mail.delivered?
        air_mail.delivered_at = op_time
        if op_time.to_date.eql?(air_mail.flight_date.to_date)
          air_mail.is_delivered_in_time = true
        end
      end

      air_mail.set_last_trace x

      air_mail.save!
    end
  end

  def self.get_last_trace(traces)
    delivered_code = ['704', '748', '747']
    returns_code = ["708", '711']
    delete_code = ["207"]
    
    last_trace = traces.reject{|x| ! x['opCode'].in? delete_code}
    last_trace = traces.reject{|x| ! x['opCode'].in? returns_code} if last_trace.blank?
    last_trace = traces.reject{|x| ! x['opCode'].in? delivered_code} if last_trace.blank?
    last_trace = traces if last_trace.blank?

    return last_trace
  end

  def set_last_trace last_trace
    return if last_trace.blank?
    if self.last_op_at < last_trace["opTime"]
      self.last_op_at = last_trace["opTime"]
      self.last_op_desc = last_trace["opDesc"]
      self.last_unit_name = last_trace["opOrgName"]
      self.last_unit_no = last_trace["opOrgCode"]
      self.last_unit = Unit.find_by no: last_trace["opOrgCode"]
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
