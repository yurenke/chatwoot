class Api::V1::Accounts::FaqDocumentsController < Api::V1::Accounts::BaseController
  before_action :ensure_admin!

  def index
    s3 = Aws::S3::Client.new(region: ENV['AWS_REGION'])
    bucket = ENV['S3_FAQ_BUCKET_NAME']
    folder = "#{ENV['S3_FAQ_FOLDER_NAME'].chomp('/')}/"

    resp = s3.list_objects_v2(bucket: bucket, prefix: folder)
    objects = resp.contents.reject { |obj| obj.key.end_with?('/') }

    status_map = {}
    objects.each do |obj|
      next unless obj.key.end_with?('.status.json')

      begin
        body = s3.get_object(bucket: bucket, key: obj.key).body.read
        data = JSON.parse(body)
        base_name = File.basename(obj.key, '.status.json')
        status_map[base_name] = {
          status: data['status'],
          updated_at: data['updated_at'] ? Time.parse(data['updated_at']) : nil
        }
      rescue StandardError => e
        Rails.logger.error("Failed to read status file #{obj.key}: #{e}")
      end
    end

    files = objects.select { |obj| obj.key.end_with?('.xlsx') }.map do |obj|
      base_name = File.basename(obj.key, '.xlsx')
      status_info = status_map[base_name]

      status =
        if status_info.nil?
          'uploaded'
        else
          updated_at = status_info[:updated_at]
          if updated_at && updated_at < obj.last_modified
            'uploaded'
          else
            status_info[:status]
          end
        end

      {
        key: obj.key,
        filename: File.basename(obj.key),
        size: obj.size,
        created_at: obj.last_modified,
        status: status
      }
    end

    render json: files
  end

  def upload_url
    filename = params[:filename]
    content_type = params[:content_type]

    folder = "#{ENV['S3_FAQ_FOLDER_NAME'].chomp('/')}/"
    key = "#{folder}#{filename}"

    presigner = Aws::S3::Presigner.new
    url = presigner.presigned_url(
      :put_object,
      bucket: ENV['S3_FAQ_BUCKET_NAME'],
      key: key,
      expires_in: 600,
      content_type: content_type
    )

    render json: { url: url, key: key }
  end

  # DELETE: 刪除檔案 + 對應 .status.json
  def destroy
    key = params[:key]
    return render json: { error: 'Missing key' }, status: :bad_request if key.blank?
    
    s3 = Aws::S3::Client.new(region: ENV['AWS_REGION'])
    bucket = ENV['S3_FAQ_BUCKET_NAME']

    begin
      # 刪除 XLSX
      s3.delete_object(bucket: bucket, key: key)

      # 刪除對應 .status.json
      status_key = "#{File.dirname(key)}/#{File.basename(key, '.xlsx')}.status.json"
      begin
        s3.delete_object(bucket: bucket, key: status_key)
      rescue Aws::S3::Errors::NoSuchKey
        # 如果 status.json 不存在，忽略
      end

      render json: { success: true }
    rescue StandardError => e
      Rails.logger.error("Failed to delete file #{key} or status.json: #{e}")
      render json: { error: 'Failed to delete file' }, status: :internal_server_error
    end
  end

  private

  def ensure_admin!
    return if Current.user&.administrator?
    render json: { error: 'Forbidden' }, status: :forbidden
  end
end