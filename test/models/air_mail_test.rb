require 'test_helper'

class AirMailTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end

  # PkpWaybillBase.create(waybill_no:'1272448151316', sender_province_no: '440000', receiver_province_no: '310000', sender_province_name: '广东省', sender_city_name: '广州市', sender_county_name: '越秀区', real_weight: '134', fee_weight: '134', postage_paid: '6', biz_occur_date: Time.now, transfer_type: '1', receiver_province_name: '上海市', receiver_city_name: '上海市', receiver_county_name: '静安区')

  test "create_air_mails" do
    AirMail.where(mail_no: '1272448151316').destroy_all

    msg_hash= JSON.parse('[{"opOrgCode":"20120015","opName":"航班降落","opTime":"2024-12-26 04:57:00","traceNo":"1272448151316","opDesc":"快件到达【上海市】，准备发往【上海市寄递事业部航空中心嘉民包件车间】","operatorNo":"XTZD","vehicleCode":"CF9025","opCode":"912","opOrgName":"上海市寄递事业部航空中心嘉民包件车间","opOrgProvName":"上海市","operatorName":"系统自动","opOrgCity":"上海市"}]')
    AirMail.create_air_mails! msg_hash
    assert AirMail.where(mail_no: '1272448151316').exists? 
    assert AirMail.find_by(mail_no: '1272448151316').import? 
  # end

  # test "refresh_transfer_air_mails" do
    msg_hash = JSON.parse('[{"opOrgCode":"20120015","opName":"邮件到达处理中心","opTime":"2024-12-26 05:59:32","traceNo":"1272448151316","opDesc":"快件到达【上海市寄递事业部航空中心嘉民包件车间】","operatorNo":"XTZD","vehicleCode":"CF9025 03:00","opCode":"954","opOrgName":"上海市寄递事业部航空中心嘉民包件车间","opOrgProvName":"上海市","operatorName":"系统自动","opOrgCity":"上海市"},{"opOrgCode":"20120015","opName":"处理中心封车","opTime":"2024-12-26 06:23:49","traceNo":"1272448151316","opDesc":"快件离开【上海市寄递事业部航空中心嘉民包件车间】，正在发往下一站","operatorNo":"03457881","vehicleCode":"沪DR0179","opCode":"389","opOrgName":"上海市寄递事业部航空中心嘉民包件车间","opOrgProvName":"上海市","operatorName":"张冬强","opOrgCity":"上海市"},{"opOrgCode":"20000414","opName":"邮件到达处理中心","opTime":"2024-12-26 07:03:44","traceNo":"1272448151316","opDesc":"快件到达【上海王港快件处理中心】","operatorNo":"XTZD","vehicleCode":"沪DR0179","opCode":"954","opOrgName":"上海王港邮件处理中心","opOrgProvName":"上海市","operatorName":"系统自动","opOrgCity":"上海市"},{"opOrgCode":"20000414","opName":"处理中心封车","opTime":"2024-12-26 12:33:20","traceNo":"1272448151316","opDesc":"快件离开【上海王港快件处理中心】，正在发往下一站","operatorNo":"2000041449002","vehicleCode":"沪FK2161","opCode":"389","opOrgName":"上海王港邮件处理中心","opOrgProvName":"上海市","operatorName":"姜志涛","opOrgCity":"上海市"}]')
    AirMail.refresh_transfer_air_mails! msg_hash
    air_mail = AirMail.find_by(mail_no: '1272448151316')
    assert air_mail.is_arrive_jm
    assert air_mail.is_leave_jm
    assert air_mail.is_arrive_center
    assert air_mail.is_leave_center
    assert air_mail.is_leave_center_in_time 
  # end

    msg_hash = JSON.parse('[{"opOrgCode":"20000414","opName":"邮件到达处理中心","opTime":"2024-12-26 06:03:44","traceNo":"1272448151316","opDesc":"快件到达【上海王港快件处理中心】","operatorNo":"XTZD","vehicleCode":"沪DR0179","opCode":"954","opOrgName":"上海王港邮件处理中心","opOrgProvName":"上海市","operatorName":"系统自动","opOrgCity":"上海市"},{"opOrgCode":"20000414","opName":"处理中心封车","opTime":"2024-12-26 10:33:20","traceNo":"1272448151316","opDesc":"快件离开【上海王港快件处理中心】，正在发往下一站","operatorNo":"2000041449002","vehicleCode":"沪FK2161","opCode":"389","opOrgName":"上海王港邮件处理中心","opOrgProvName":"上海市","operatorName":"姜志涛","opOrgCity":"上海市"}]')
    assert (air_mail.arrive_center_at > '2024-12-26 07:00'.to_time )
    assert (air_mail.leave_center_at > '2024-12-26 12:00'.to_time)
    AirMail.refresh_transfer_air_mails! msg_hash
    air_mail = AirMail.find_by(mail_no: '1272448151316')
    assert (air_mail.arrive_center_at < '2024-12-26 07:00'.to_time )
    assert (air_mail.leave_center_at < '2024-12-26 12:00'.to_time)

  # test "refresh_in_delivery_air_mails" do
    msg_hash = JSON.parse('[{"opOrgCode":"20008605","opName":"揽投解车","opTime":"2024-12-26 15:26:55","traceNo":"1272448151316","opDesc":"快件到达【上海市虹口区飞虹路揽投部】","operatorNo":"2000860598127","vehicleCode":"vehicleCode","opCode":"306","opOrgName":"上海市虹口区飞虹路揽投部","opOrgProvName":"上海市","operatorName":"卢建强","opOrgCity":"上海市"}, {"opOrgCode":"20008605","opName":"投递邮件接收-下段","opTime":"2024-12-26 15:31:55","traceNo":"1272448151316","opDesc":"快件正在派送中，请耐心等待，保持电话畅通，准备签收，如有疑问请电联快递员【卢建强，电话:13564771339】或揽投部【电话:021-35326625】，投诉请致电11183。","operatorNo":"2000860598127","vehicleCode":"vehicleCode","opCode":"702","opOrgName":"上海市虹口区飞虹路揽投部","opOrgProvName":"上海市","operatorName":"卢建强","opOrgCity":"上海市"}, {"opOrgCode":"20008605","opName":"投递结果反馈-未妥投","opTime":"2024-12-26 18:28:09","traceNo":"1272448151316","opDesc":"因收件人名址有误/不详且电话无法接通，将再次联系收件人进行投递，如有疑问请电联快递员【电话:13564771339】，投诉请致电11183。","operatorNo":"2000860598127","vehicleCode":"vehicleCode","opCode":"705","opOrgName":"上海市虹口区飞虹路揽投部","opOrgProvName":"上海市","operatorName":"卢建强","opOrgCity":"上海市"}, {"opOrgCode":"20008605","opName":"投递邮件接收-下段","opTime":"2024-12-27 11:29:59","traceNo":"1272448151316","opDesc":"快件正在派送中，请耐心等待，保持电话畅通，准备签收，如有疑问请电联快递员【卢建强，电话:13564771339】或揽投部【电话:021-35326625】，投诉请致电11183。","operatorNo":"2000860598127","vehicleCode":"vehicleCode","opCode":"702","opOrgName":"上海市虹口区飞虹路揽投部","opOrgProvName":"上海市","operatorName":"卢建强","opOrgCity":"上海市"}, {"opOrgCode":"20008605","opName":"投递结果反馈-妥投","opTime":"2024-12-27 12:32:28","traceNo":"1272448151316","opDesc":"您的快件已代签收【家人，，】，如有疑问请电联快递员【卢建强，电话:13564771339】。连接美好，无处不在，感谢您使用中国邮政，期待再次为您服务。","operatorNo":"2000860598127","vehicleCode":"vehicleCode","opCode":"704","opOrgName":"上海市虹口区飞虹路揽投部","opOrgProvName":"上海市","operatorName":"卢建强","opOrgCity":"上海市"}]')

    AirMail.refresh_in_delivery_air_mails! msg_hash
    air_mail = AirMail.find_by(mail_no: '1272448151316')
    assert air_mail.is_arrive_sub
    assert air_mail.is_in_delivery
  # end

  # test "refresh_delivered_air_mails" do
    msg_hash = JSON.parse('[{"opOrgCode":"20008605","opName":"投递结果反馈-未妥投","opTime":"2024-12-26 18:28:09","traceNo":"1272448151316","opDesc":"因收件人名址有误/不详且电话无法接通，将再次联系收件人进行投递，如有疑问请电联快递员【电话:13564771339】，投诉请致电11183。","operatorNo":"2000860598127","vehicleCode":"vehicleCode","opCode":"705","opOrgName":"上海市虹口区飞虹路揽投部","opOrgProvName":"上海市","operatorName":"卢建强","opOrgCity":"上海市"}, {"opOrgCode":"20008605","opName":"投递邮件接收-下段","opTime":"2024-12-27 11:29:59","traceNo":"1272448151316","opDesc":"快件正在派送中，请耐心等待，保持电话畅通，准备签收，如有疑问请电联快递员【卢建强，电话:13564771339】或揽投部【电话:021-35326625】，投诉请致电11183。","operatorNo":"2000860598127","vehicleCode":"vehicleCode","opCode":"702","opOrgName":"上海市虹口区飞虹路揽投部","opOrgProvName":"上海市","operatorName":"卢建强","opOrgCity":"上海市"}, {"opOrgCode":"20008605","opName":"投递结果反馈-妥投","opTime":"2024-12-27 12:32:28","traceNo":"1272448151316","opDesc":"您的快件已代签收【家人，，】，如有疑问请电联快递员【卢建强，电话:13564771339】。连接美好，无处不在，感谢您使用中国邮政，期待再次为您服务。","operatorNo":"2000860598127","vehicleCode":"vehicleCode","opCode":"704","opOrgName":"上海市虹口区飞虹路揽投部","opOrgProvName":"上海市","operatorName":"卢建强","opOrgCity":"上海市"}]')

    AirMail.refresh_delivered_air_mails! msg_hash

    air_mail = AirMail.find_by(mail_no: '1272448151316')
    assert air_mail.delivered?
    assert ! air_mail.delivered_at.blank?
    assert ! air_mail.is_delivered_in_time
  end
end
