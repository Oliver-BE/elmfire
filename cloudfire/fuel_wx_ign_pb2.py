# -*- coding: utf-8 -*-
# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: fuel_wx_ign.proto
"""Generated protocol buffer code."""
from google.protobuf.internal import builder as _builder
from google.protobuf import descriptor as _descriptor
from google.protobuf import descriptor_pool as _descriptor_pool
from google.protobuf import symbol_database as _symbol_database
# @@protoc_insertion_point(imports)

_sym_db = _symbol_database.Default()




DESCRIPTOR = _descriptor_pool.Default().AddSerializedFile(b'\n\x11\x66uel_wx_ign.proto\"\xfb\x03\n\x07Request\x12\x0c\n\x04name\x18\x01 \x01(\t\x12\x12\n\ncenter_lat\x18\x02 \x01(\x02\x12\x12\n\ncenter_lon\x18\x03 \x01(\x02\x12\x13\n\x0bwest_buffer\x18\x04 \x01(\x02\x12\x13\n\x0b\x65\x61st_buffer\x18\x05 \x01(\x02\x12\x14\n\x0csouth_buffer\x18\x06 \x01(\x02\x12\x14\n\x0cnorth_buffer\x18\x07 \x01(\x02\x12\x0f\n\x07\x64o_fuel\x18\x08 \x01(\x08\x12\x13\n\x0b\x66uel_source\x18\t \x01(\t\x12\x14\n\x0c\x66uel_version\x18\n \x01(\t\x12\r\n\x05\x64o_wx\x18\x0b \x01(\x08\x12\x0f\n\x07wx_type\x18\x0c \x01(\t\x12\x15\n\rwx_start_time\x18\r \x01(\t\x12\x14\n\x0cwx_num_hours\x18\x0e \x01(\x05\x12\x13\n\x0b\x64o_ignition\x18\x0f \x01(\x08\x12\x16\n\x0epoint_ignition\x18\x10 \x01(\x08\x12\x18\n\x10polygon_ignition\x18\x11 \x01(\x08\x12\x14\n\x0cignition_lat\x18\x12 \x01(\x02\x12\x14\n\x0cignition_lon\x18\x13 \x01(\x02\x12\x1d\n\x15\x61\x63tive_fire_timestamp\x18\x14 \x01(\t\x12 \n\x18\x61lready_burned_timestamp\x18\x15 \x01(\t\x12\x17\n\x0fignition_radius\x18\x16 \x01(\x02\x12\x0e\n\x06outdir\x18\x17 \x01(\t\"E\n\x05Reply\x12\x16\n\x0estatus_message\x18\x01 \x01(\t\x12\x13\n\x0bstatus_code\x18\x02 \x01(\x05\x12\x0f\n\x07\x66ileloc\x18\x03 \x01(\t20\n\tFuelWxIgn\x12#\n\rGetDomainData\x12\x08.Request\x1a\x06.Reply\"\x00\x62\x06proto3')

_builder.BuildMessageAndEnumDescriptors(DESCRIPTOR, globals())
_builder.BuildTopDescriptorsAndMessages(DESCRIPTOR, 'fuel_wx_ign_pb2', globals())
if _descriptor._USE_C_DESCRIPTORS == False:

  DESCRIPTOR._options = None
  _REQUEST._serialized_start=22
  _REQUEST._serialized_end=529
  _REPLY._serialized_start=531
  _REPLY._serialized_end=600
  _FUELWXIGN._serialized_start=602
  _FUELWXIGN._serialized_end=650
# @@protoc_insertion_point(module_scope)
