class DeepspeechController < ApplicationController
   protect_from_forgery with: :null_session
   skip_before_action :verify_authenticity_token

   def home
     data = {message: "hello"}
     $redis.lpush("create_job", data.to_json)
   end

   def create_job
    audio = params[:file]
    if audio.nil?
      data = "{\"message\" : \"file not found\"}"
      render :json=>data
      return
    end
    job_id = generate_job_id
    File.open("#{Rails.root}/storage/#{job_id}/audio.wav","wb") do |file|
      file.write audio.read
    end
      set_status(job_id)
      data = {"job_id" => job_id}
      render :json=>data
      $redis.lpush("transcript", data.to_json)
  end

  def check_status
    job_id = params[:job_id]
    if job_id.nil?
      data = "{\"message\" : \"job_id not found\"}"
      render :json=>data
      return
    end
    db =  SQLite3::Database.open "db/development.sqlite3"
    status = db.get_first_row "select status from job_statuses where job_id = '#{job_id}'"
    db.close
    if status.nil?
      data = "{\"message\" : \"No job_id found\"}"
      render :json=>data
      return
    end
    data = "{\"status\" : \"#{status[0]}\"}"
    render :json=>data
  end

  def transcript
    job_id = params[:job_id]
    if job_id.nil?
      data = "{\"message\" : \"job_id not found\"}"
      render :json=>data
      return
    end
    data = "{\"message\" : \"File not found. Please check if job_id is correct and make sure status is completed\"}"
    if File.exist?("#{Rails.root}/storage/#{job_id}/audio.json")
      file = File.open("#{Rails.root}/storage/#{job_id}/audio.json")
      data = JSON.load file
    end
    render :json=>data
  end

  private
  def generate_job_id
    jobID = SecureRandom.hex(10)
    Dir.chdir "#{Rails.root}/storage"
    system("mkdir #{jobID}")
    Dir.chdir "#{Rails.root}"
    return jobID
  end

  def set_status(job_id)
    status = "pending"
    db = SQLite3::Database.open "db/development.sqlite3"
    query = "INSERT INTO job_statuses (jobID, status, created_at, updated_at) VALUES ('#{job_id}', '#{status}', '#{Time.now}', '#{Time.now}')"
    db.execute(query)
    db.close
  end
end
