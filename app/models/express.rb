class Express < ApplicationRecord
  belongs_to :post_unit, class_name: 'Unit', optional: true
  belongs_to :last_unit, class_name: 'Unit', optional: true

  has_one :post_parent_unit, class_name: 'Unit', through: :post_unit, source: 'parent_unit'
  has_one :last_parent_unit, class_name: 'Unit', through: :last_unit, source: 'parent_unit'

  belongs_to :pre_express, class_name: 'Express', optional: true
  belongs_to :receipt_express, class_name: 'Express', optional: true

  validates_presence_of :express_no, :business_id, :message => '不能为空'
  
  enum status: {waiting: 'waiting', delivered: 'delivered', returns: 'returns', del: 'del'}
  STATUS_NAME = { waiting: '未妥投', delivered: '妥投', returns: '退回'}

  enum whereis: {in_transit: 'in_transit', delivery_part: 'delivery part'}
  WHEREIS_NAME = {in_transit: '在途中', delivery_part: '投递端'}

  enum delivered_status: {own: 'own', other: 'other', unit: 'unit'}
  DELIVERED_STATUS = {own: '本人收', other: '他人收', unit: '单位/快递柜'}

  #enum base_product_no: {standard_express: '11210', express_package: '11312'}
  BASE_PRODUCT_NAME = {standard_express: '标快', express_package: '快包', other_product: '其他'}
  BASE_PRODUCT_NOS =  {standard_express: '11210', express_package: '11312'}
  BASE_PRODUCT_SELECT = {'11210' => '标快', '11312' => '快包', other_product: '其他'}

  enum receipt_flag: {forward: 'forward', receipt: 'receipt', no_receipt_flag: nil}
  RECEIPT_FLAG = {forward: '正向邮件', receipt: '反向邮件', no_receipt_flag: '普通邮件'}
  RECEIPT_FLAG_SELECT = {forward: '正向邮件', receipt: '反向邮件', null: '普通邮件'}

  enum receipt_status: {receipt_receive: 'receipt_receive', no_receipt_receive: nil, receipt_delivered: 'receipt_delivered'}
  RECEIPT_STATUS = {receipt_receive: '已收寄', no_receipt_receive: '未收寄', receipt_delivered: '已妥投'}
  RECEIPT_STATUS_SELECT = {receipt_receive: '已收寄', null: '未收寄', receipt_delivered: '已妥投'}

  DISTRIBUTIVE_CENTER_NAME = { '21112100': '南京集航'}

  TRANSFER_TYPE_NAME = {all_land: '全陆运', other_type: '其他'}
  TRANSFER_TYPE_NOS =  {all_land: '3'}
  TRANSFER_TYPE_SELECT = {'3' => '全陆运', other_type: '其他'}

  ARRIVE_SUB_OP_CODE = '306'
  IN_DELIVERY_OP_CODE = '702'
  DELIVERY_FAILURE_OP_CODE = '705'

  DELIVERY_PART_CODE = ['306', '307', '702', '705']
  

  #for karafka_eff
  def self.refresh_traces! msg_hash
    #init message
    express_no = msg_hash.first["traceNo"]

    last_trace = Express.get_last_trace msg_hash

    express = self.waiting.where("last_op_at < '#{last_trace['opTime']}'").or(Express.where(last_op_at:nil)).find_by(express_no: express_no)

    #only update not waiting express to avoid repeating
    if ! express.blank? && express.waiting? 
      express.refresh_trace! last_trace
      return true
    else
      return false
    end
  end

  #for karafka_eff
  def refresh_trace! last_trace = nil
    self.refresh_trace last_trace

    # Rails.logger.error("======express_no #{self.express_no}, status #{self.status}, at #{self.last_op_at}, desc #{self.last_op_desc}======")

    if ! self.del?
      self.save!
    else
      self.destroy!
    end
  end

  def refresh_trace last_trace
    # last_trace = Express.get_last_trace traces

    # return if last_trace.blank?
    self.last_op_at = last_trace["opTime"]
    self.last_op_desc = last_trace["opDesc"]
    self.last_unit_name = last_trace["opOrgName"]
    self.last_unit_no = last_trace["opOrgCode"]
    self.last_unit = Unit.find_by no: last_trace["opOrgCode"]

    opCode = last_trace["opCode"]
    
    self.whereis = self.waiting? ? Express.to_whereis(opCode) : nil


    #for zmrs中免日上
    if opCode.eql? ARRIVE_SUB_OP_CODE
      self.is_arrive_sub  = true
    elsif opCode.eql? IN_DELIVERY_OP_CODE
      self.is_arrive_sub  = true
      self.is_in_delivery = true
    elsif opCode.eql? DELIVERY_FAILURE_OP_CODE
      self.is_arrive_sub  = true
      self.is_in_delivery = true
      self.is_delivery_failure = true
    end

    self.status = Express.get_status(opCode)

    # 4 dewu
    self.last_prov = last_trace["opOrgProvName"]
    self.last_city = last_trace["opOrgCity"]
    self.is_change_addr = true if opCode.eql?("802")
    self.is_cancelled  = true if opCode.eql?("801")

    begin
      self.delivered_status = Express.get_delivered_status(opCode, last_trace["opDesc"])
    rescue
    end

    self.fill_delivered_days

    if self.receipt? && self.delivered?
      self.pre_express.try(:receipt_delivered!)
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

  def self.get_status(opt_code)
    delivered_code = ['704', '748', '747']
    returns_code = ["708", '711']
    delete_code = ["207"]

    status = Express::statuses[:del] if opt_code.in? delete_code
    status ||= Express::statuses[:returns] if opt_code.in? returns_code
    status ||= Express::statuses[:delivered] if opt_code.in? delivered_code
    status ||= Express::statuses[:waiting]

    return status
  end

  def self.get_delivered_status(opt_code, opt_desc)
    if !opt_code.blank?
      if opt_code.eql? '704'
        if opt_desc.include? '已妥收'
          delivered_status = Express::delivered_statuses[:own]
        elsif opt_desc.include? '已代收' && (opt_desc.include?('家人') || opt_desc.include?('朋友') || opt_desc.include?('同事') || opt_desc.include?('邻居'))
          delivered_status = Express::delivered_statuses[:other]
        else
          delivered_status = Express::delivered_statuses[:unit]
        end
      elsif opt_code.eql? '748'
        delivered_status = Express::delivered_statuses[:own]
      elsif opt_code.eql? '747'
        delivered_status = Express::delivered_statuses[:unit]
      end
    end
  end

  def self.to_whereis(code)
    if code.in? DELIVERY_PART_CODE
      whereis[:delivery_part]
    else
      whereis[:in_transit]
    end
  end

  def fill_delivered_days
    if delivered? || returns?
      if ! posting_date.blank? && ! last_op_at.blank?
         self.delivered_hour = last_op_at.hour
         self.delivered_days = last_op_at.to_date - posting_date.to_date - ((delivered_hour < 12) ? 0.5 : 0)
         return 
      end
    end
    self.delivered_hour = nil
    self.delivered_days = nil
  end

  ###############for karafka eff###############

end


