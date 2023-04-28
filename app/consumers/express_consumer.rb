class ExpressConsumer < ApplicationConsumer
	@@mail_lock = Mutex.new

	def consume
		consume_without_thread
		# consume_without_thread
	end

	def consume_without_thread
  	id = rand
  	t1 = Time.now
  	Rails.logger.error "============#{id} #{t1} #{params_batch.size}============"
  	ActiveRecord::Base.transaction do
	    params_batch.each do |message|
	      # puts "Message payload: #{message.payload}"
	      begin
	      	if ! message.blank?
	      		message_hash = message.payload
	      	# sleep(0.1)
		      	ExpressConsumer.refresh_trace(message_hash, Time.now)
		      end
	      rescue Exception => e
	      	@error_msg = "#{e.class.name} #{e.message}"
	      	Rails.logger.error("#{e.class.name} #{e.message}")
	      	
	      	e.backtrace.each do |x|
			      @error_msg += "\n#{x}"
			      Rails.logger.error(x)
			    end

			    # InterfaceLog.log("express_consumer", "consume", false, {request_url: "", params: message_hash, response_body: "", request_ip: "", business_code: "", parent: "", error_msg: @error_msg}) #if @status.eql? false#if Rails.env.development?
	      end
	    end
	  end
	  t2 = Time.now
	  Rails.logger.error "============#{id} #{t2} #{t2-t1}============"
  end

  def consume_with_thread
  	id = rand
  	t1 = Time.now
  	Rails.logger.error "============#{id} #{t1} #{params_batch.size}============"

		batch_size = params_batch.size
		
		message_array = params_batch.to_a
		thread_size = batch_size > 20 ? 20 : batch_size

		threads = []

		thread_size.times.each do |i|
    	t = Thread.new do
    		# ActiveRecord::Base.transaction do
	    		while message_array.size > 0
		      	begin
			      	message = nil
			      	@@mail_lock.synchronize do
			      		message = message_array.pop
			      	end

			      	if ! message.blank?
				      	message_hash = message.payload
				      	# sleep(0.1)
					      
		      			Express.refresh_trace(message_hash, Time.now)
		      		end
		      	rescue Exception => e
			      	@error_msg = "#{e.class.name} #{e.message}"
			      	# Rails.logger.error("#{e.class.name} #{e.message}")
			      	
			      	e.backtrace.each do |x|
					      @error_msg += "\n#{x}"
					      # Rails.logger.error(x)
					    end

					    # InterfaceLog.log("express_consumer", "consume", false, {request_url: "", params: message_hash.to_json, response_body: "", request_ip: "", business_code: "", parent: "", error_msg: @error_msg})
					  end
					end
				# end
	    end

	    threads << t

    end
    threads.each {|t| t.join}

    t2 = Time.now
	  Rails.logger.error "============#{id} #{t2} #{t2-t1}============"
  end


  def self.refresh_trace msg_hash, received_at
    #init message
    express_no = msg_hash.first["traceNo"]

    last_trace = Express.get_last_trace msg_hash

    express = Express.waiting.where("last_op_at < '#{last_trace['opTime']}'").find_by(express_no: express_no)

    #only update not waiting express to avoid repeating
    if ! express.blank? && express.waiting? 
      express.refresh_trace! last_trace
      return
    end

    traces = InternationalExpress.get_traces msg_hash

  	international_express = InternationalExpress.waiting.find_by(express_no: express_no)

  	if ! international_express.blank? && international_express.waiting? 
  		international_express.refresh_traces! traces
  	end
  end
end