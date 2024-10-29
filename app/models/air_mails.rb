class AirMails < ApplicationRecord

  def self.refresh_traces! msg_hash
    guangzhou_aircenter_code = '51000061'
    op_code = '389'

    mails = msg_hash.reject{|x| ! x['opOrgCode'].eql?(guangzhou_aircenter_code)}.reject{|x| ! x['opCode'].eql?(op_code)}.sort{|x,y| x["opTime"] <=> y["opTime"]}

    mails.each do |x|
      mail_no = x['traceNo']
      op_time = x["opTime"].to_time
      
      last_op_at = 
      next if AirMails.exists?(mail_no: mail_no)

      air_mail = AirMails.new
      air_mail.mail_no = mail_no
      air_mail.last_op_at = op_time
      air_mail.last_op_desc = x["opDesc"]
      air_mail.last_unit_name = x["opOrgName"]

      pkp = PkpWaybillBase.where(waybill_no: mail_no).last
      if ! pkp.blank?
        air_mail.sender_city_name = pkp.sender_city_name
        air_mail.sender_county_name = pkp.sender_county_name
        air_mail.real_weight = pkp.real_weight
        air_mail.fee_weight = pkp.fee_weight
        air_mail.order_weight = pkp.order_weight
        air_mail.postage_paid = pkp.postage_paid
        air_mail.postage_total = pkp.postage_total
        air_mail.posting_date = pkp.posting_date
        air_mail.transfer_type = pkp.transfer_type
      end

      air_mail.save!
    end
  end

end