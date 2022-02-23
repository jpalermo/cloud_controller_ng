# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: evacuation.proto

require 'google/protobuf'

require 'actual_lrp_pb'
require 'error_pb'
Google::Protobuf::DescriptorPool.generated_pool.build do
  add_message "diego.bbs.models.EvacuationResponse" do
    optional :error, :message, 1, "diego.bbs.models.Error"
    optional :keep_container, :bool, 2
  end
  add_message "diego.bbs.models.EvacuateClaimedActualLRPRequest" do
    optional :actual_lrp_key, :message, 1, "diego.bbs.models.ActualLRPKey"
    optional :actual_lrp_instance_key, :message, 2, "diego.bbs.models.ActualLRPInstanceKey"
  end
  add_message "diego.bbs.models.EvacuateRunningActualLRPRequest" do
    optional :actual_lrp_key, :message, 1, "diego.bbs.models.ActualLRPKey"
    optional :actual_lrp_instance_key, :message, 2, "diego.bbs.models.ActualLRPInstanceKey"
    optional :actual_lrp_net_info, :message, 3, "diego.bbs.models.ActualLRPNetInfo"
    repeated :actual_lrp_internal_routes, :message, 5, "diego.bbs.models.ActualLRPInternalRoute"
  end
  add_message "diego.bbs.models.EvacuateStoppedActualLRPRequest" do
    optional :actual_lrp_key, :message, 1, "diego.bbs.models.ActualLRPKey"
    optional :actual_lrp_instance_key, :message, 2, "diego.bbs.models.ActualLRPInstanceKey"
  end
  add_message "diego.bbs.models.EvacuateCrashedActualLRPRequest" do
    optional :actual_lrp_key, :message, 1, "diego.bbs.models.ActualLRPKey"
    optional :actual_lrp_instance_key, :message, 2, "diego.bbs.models.ActualLRPInstanceKey"
    optional :error_message, :string, 3
  end
  add_message "diego.bbs.models.RemoveEvacuatingActualLRPRequest" do
    optional :actual_lrp_key, :message, 1, "diego.bbs.models.ActualLRPKey"
    optional :actual_lrp_instance_key, :message, 2, "diego.bbs.models.ActualLRPInstanceKey"
  end
  add_message "diego.bbs.models.RemoveEvacuatingActualLRPResponse" do
    optional :error, :message, 1, "diego.bbs.models.Error"
  end
end

module Diego
  module Bbs
    module Models
      EvacuationResponse = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.EvacuationResponse").msgclass
      EvacuateClaimedActualLRPRequest = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.EvacuateClaimedActualLRPRequest").msgclass
      EvacuateRunningActualLRPRequest = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.EvacuateRunningActualLRPRequest").msgclass
      EvacuateStoppedActualLRPRequest = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.EvacuateStoppedActualLRPRequest").msgclass
      EvacuateCrashedActualLRPRequest = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.EvacuateCrashedActualLRPRequest").msgclass
      RemoveEvacuatingActualLRPRequest = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.RemoveEvacuatingActualLRPRequest").msgclass
      RemoveEvacuatingActualLRPResponse = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.RemoveEvacuatingActualLRPResponse").msgclass
    end
  end
end
