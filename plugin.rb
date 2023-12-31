# name: Topic Metadata
# about:
# version: 0.1
# authors: 
enabled_site_setting :topic_metadata_external_website
after_initialize do
  PostsController.class_eval do
    alias_method :oldPostCreateMethod, :create
    def create
      oldPostCreateReturnedData = oldPostCreateMethod
      isPostCreated = false
      postCreatedId= -1
      begin
       retrurnDataJson = JSON.parse(oldPostCreateReturnedData)
       if(retrurnDataJson.has_key?("post"))
         if(retrurnDataJson["post"].has_key?("id"))
           isPostCreated=true
           postCreatedId = retrurnDataJson["post"]["id"]
          end
       end
      rescue
      end
      unless isPostCreated == false
        topicid =  postCreatedId  
        projectid = params[:projectidc]
        metadata = params[:metadatac]
        unless projectid.nil?
          begin
            url = SiteSetting.topic_metadata_external_website.gsub('{projectid}', projectid)
            connection = Excon.new(url)
            response = connection.request(expects: [200, 201], method: :Get)
          rescue
          end
        end
        unless metadata.nil?
          topicmetadata =  metadata.split(',')
          objArray = Array.new
          topicmetadata.each do |object|
            singledata = object.split(':')
            tempMetaRec = TopicCustomField.find_by(name: 'custom_metadata', topic_id:topicid)
            if(tempMetaRec.nil?)
              metaHash = Hash[singledata[0], singledata[1]] 
              metaJson = metaHash.to_json
              metaStr  = metaJson.to_s
              TopicCustomField.create(name: "custom_metadata",value: metaStr , topic_id:topicid)
            else
              tempMetaValue =  JSON.parse (tempMetaRec.value)
              tempMetaValue[singledata[0] ]=  singledata[1]
              tempMetaRec.value = tempMetaValue.to_json.to_s
              tempMetaRec.save       
            end                
          end
        end
      end
    return oldPostCreateReturnedData
    end
  end
  module ::CustomTopicMetaData
        class Engine < ::Rails::Engine
            engine_name "custom_topic_metadata"
          isolate_namespace CustomTopicMetaData
      end
  end
  class CustomTopicMetaData::TopicmetadataController < Admin::AdminController
      def set_metadata
        topicdata = params[:data]
        topicid = params[:topic_id]
        topicRec = Topic.find_by_id(topicid)
        unless topicRec.nil?
          topicmetadata =  params[:data].split(',')
          objArray = Array.new
          topicmetadata.each do |object|
            singledata = object.split(':')
            tempMetaRec = TopicCustomField.find_by(name: 'custom_metadata', topic_id:params[:topic_id])
            if(tempMetaRec.nil?)
              metaHash = Hash[singledata[0], singledata[1]] 
              metaJson = metaHash.to_json
              metaStr  = metaJson.to_s
              TopicCustomField.create(name: "custom_metadata",value: metaStr , topic_id:params[:topic_id])
            else
              tempMetaValue =  JSON.parse (tempMetaRec.value)
              tempMetaValue[singledata[0] ]=  singledata[1]
              tempMetaRec.value = tempMetaValue.to_json.to_s
              tempMetaRec.save       
            end                
            
          end
        end
         render :json =>params[:data], :status => 200
      end
     def search_metadata
        topicmetadata =  params[:data].split(',')
        searchtype = params[:searchtype]
        query_chain = TopicCustomField.where(name:"custom_metadata")
        searchArr = Array.new
        topicmetadata.each do |object|
          singledata = object.split(':')
          query_chain = query_chain.where("value::jsonb->>'"+singledata[0]+"' = ?", singledata[1])
        end
        objArray = Array.new
        query_chain.each do |object|
         objArray << object.topic_id
        end
       render :json =>objArray.to_json, :status => 200
     end
     def view_metadata
        topic_id =  params[:id]
        topicMetadataQuery =  TopicCustomField.where(name:"custom_metadata",topic_id:topic_id).first
        topicMetaData = ''
        unless topicMetadataQuery.nil?
          topicMetaData  = topicMetadataQuery.value
        end
        render :json => topicMetaData, :status => 200
     end
     def delete_metadata
        topic_id =  params[:id]
        key =  params[:key]
        output = "{}"
        topic_metadata =  TopicCustomField.find_by(name:"custom_metadata",topic_id:topic_id)
        unless topic_metadata.nil?
          metaJson = JSON.parse(topic_metadata.value)
          metaJson.delete(key)      
          topic_metadata.value = metaJson.to_json.to_s
          topic_metadata.save
          output = topic_metadata.value
        end
        render :json => output, :status => 200  
     end
 end
  CustomTopicMetaData::Engine.routes.draw do
      get '/topic_metadata_api/setmetadata/:topic_id/:data' => 'topicmetadata#set_metadata' 
      get '/topic_metadata_api/searchmetadata/:data' => 'topicmetadata#search_metadata' 
      get '/topic_metadata_api/viewmetadata/:id' => 'topicmetadata#view_metadata'
      get '/topic_metadata_api/deletemetadata/:id/:key' => 'topicmetadata#delete_metadata' 
  end
  Discourse::Application.routes.append do
      mount ::CustomTopicMetaData::Engine, at: "/"
    end
end
