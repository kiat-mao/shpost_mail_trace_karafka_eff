class MailTrace < ApplicationRecord
  has_many :mail_trace_details
  # validates_presence_of :mail_no, :message => '不能为空'
  # validates_uniqueness_of :mail_no, :message => '该挂号编号已存在'

  STATUS = { own: 'own', other: 'other', unit: 'unit', returns: 'returns', waiting: 'waiting', del: 'del'}

  STATUS_SHOW = { own: '本人收', other: '他人收', unit: '单位收', returns: '退件', waiting: '未妥投', del: '删除'}

  STATUS_DELIVERED = [STATUS[:own], STATUS[:other], STATUS[:unit]]

  def self.save_mail_trace(msg_hash, received_at)
    # mail_nos = msg_hash['traces'].map{|x| x['traceNo']}.uniq

    # mail_nos.each do |mail_no|
      # traces = msg_hash['traces'].reject{|x| ! x['traceNo'].eql? mail_no}.sort{|x,y| x['opTime'] <=> y['opTime']}
      # ActiveRecord::Base.connection_pool.with_connection do |conn|
      # ActiveRecord::Base.transaction do
        # traces = msg_hash['traces']
    begin
      # throw Exception.new if mail_no.eql?('123')
      mail_no = msg_hash.first["traceNo"]
      traces = msg_hash

      mail_trace = MailTrace.find_by(mail_no: mail_no)

      if !mail_trace.blank?
        if mail_trace.last_received_at > received_at #In SQLITE3 May be not,cuz it will save datetime with del last precision
          return mail_trace
        else
          to_update = false
          
          last_result = get_result_with_status(traces)
          if mail_trace.status.eql? STATUS[:waiting]
            to_update = true if last_result["opt_at"].to_time >= mail_trace.operated_at
          elsif mail_trace.status.eql? STATUS[:returns]
            to_update = false
          else
            to_update = true if ! last_result["status"].eql? STATUS[:waiting]
          end

          if to_update
            mail_trace.update!(last_trace: traces.last.to_json, status: last_result["status"], result: last_result["opt_desc"], operated_at: last_result["opt_at"], is_posting: last_result["is_posting"], last_received_at: received_at)
          else
            mail_trace.update!(last_received_at: received_at)
          end
          mail_trace.mail_trace_details.create!(traces: traces.to_json)
        end
      else
        last_result = get_result_with_status(traces)

        mail_trace = MailTrace.create!(mail_no: mail_no, last_trace: traces.last.to_json, status: last_result["status"], result: last_result["opt_desc"], operated_at: last_result["opt_at"], is_posting: last_result["is_posting"], last_received_at: received_at)

        mail_trace.mail_trace_details.create!(traces: traces.to_json)
      end
    rescue ActiveRecord::RecordNotUnique => e
      Rails.logger.error("Create mail_trace unique_error: #{msg_hash}, and will be retry")
      # Rails.logger.error("#{e.class.name} #{e.message}")
      retry
    rescue Exception => e
      @error_msg = "#{e.class.name} #{e.message}"
      Rails.logger.error("#{e.class.name} #{e.message}")
      
      e.backtrace.each do |x|
        @error_msg += "\n#{x}"
        Rails.logger.error(x)
      end

      InterfaceLog.log("mail_trace", "save_mail_trace", false, {request_url: "", params: traces.to_json, response_body: "", request_ip: "", business_code: mail_no, parent: "", error_msg: @error_msg})
    end
    # end
    # end
  end

  def self.get_result_with_status(traces)
    delivered_code = ['704', '748', '747']
    return_code = ["708", '711']
    delete_code = ["207"]

    last_result = traces.reject{|x| ! x['opCode'].in? delete_code}.last
    last_result ||= traces.reject{|x| ! x['opCode'].in? return_code}.last
    last_result ||= traces.reject{|x| ! x['opCode'].in? delivered_code}.last
    last_result ||= traces.last

    opt_code = last_result["opCode"]
    opt_desc = last_result["opDesc"]
    opt_time = last_result["opTime"]
    
    status = MailTrace::STATUS[:waiting]

    if !opt_code.blank?
      if opt_code.eql? '704'
        if opt_desc.include? '本人'
          status = MailTrace::STATUS[:own]
        elsif opt_desc.include? '他人'
          status = MailTrace::STATUS[:other]
        else
          status = MailTrace::STATUS[:unit]
        end
      elsif opt_code.eql? '748'
        status = MailTrace::STATUS[:own]
      elsif opt_code.eql? '747'
        status = MailTrace::STATUS[:unit]
      elsif opt_code.eql? '207'
        status = MailTrace::STATUS[:del]
      elsif opt_code.in? return_code
        status = MailTrace::STATUS[:returns]
      end
    end
    result = {"opt_at" => opt_time, "opt_desc" => opt_desc, "status" => status}

    if status.eql? MailTrace::STATUS[:waiting]
      result["is_posting"] = traces.find{|x| x['opCode'].eql? '203' }.blank? ? false : true
    else
      result["is_posting"] = false
    end

    result
  end
end
