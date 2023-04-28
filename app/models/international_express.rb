class InternationalExpress < ApplicationRecord
  belongs_to :business, optional: true

  enum status: {waiting: 'waiting', returns: 'returns'}
  STATUS_NAME = { waiting: '未妥投', returns: '退回'}



  def refresh_traces! traces = nil
    traces.sort{|x,y| x["opTime"] <=> y["opTime"]}.each do |trace|
      self.refresh_trace trace
    end
  end

  def leaved_orig_at
    return leaved_orig_at.blank? ? posting_date : leaved_orig_at
  end

  def refresh_trace trace
    op_code = trace["opCode"]
    op_time = trace["opTime"].to_time

    #['711', '516', '460', '305', '389', '457']
    case op_code
    when '711'
      self.status = InternationalExpress::statuses[:returns] 
    when '516'
      self.is_arrived = true
      self.arrived_at = op_time
      self.arrived_hour = ((self.arrived_at - self.leaved_orig_at)/60/60).to_i + 1
    when '460'
      self.is_leaved = true
      self.leaved_at = op_time
      self.leaved_hour = ((self.leaved_at - self.leaved_orig_at)/60/60).to_i + 1
    when '305'
      self.is_leaved_orig = true
      self.leaved_orig_at = op_time
      # self.leaved_orig_hour = ((self.leaved_orig_at - self.leaved_orig_at)/60/60).to_i + 1
      self.leaved_orig_after_18 = true if op_time.hour > 18
    when '389'
      self.is_leaved_center = true
      self.leaved_center_at = op_time
      self.leaved_center_hour = ((self.leaved_center_at - self.leaved_orig_at)/60/60).to_i + 1
    when '457'
      self.is_takeoff = true
      self.takeoff_at = op_time
      self.takeoff_hour = ((self.takeoff_at - self.leaved_center_at)/60/60).to_i + 1
    end

    # return if trace.blank?
    if self.last_op_at < op_time
      self.last_op_at = op_time
      self.last_op_desc = trace["opDesc"]
      self.last_unit_name = trace["opOrgName"]
      # self.last_unit_no = trace["opOrgCode"]
      # self.last_unit = Unit.find_by no: trace["opOrgCode"]
    end
    # self.status = Express.get_status(trace["opCode"])
  end


  def self.get_traces(traces)
    codes = ['711', '516', '460', '305', '389', '457']

    return traces.reject{|x| ! x['opCode'].in? codes}
  end
end
