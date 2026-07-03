struct PEInfo {
  signer : String
  product_name : String
  company_name : String
  file_description : String
  is_dotnet : Bool
  subsystem : Int
} derive(@debug.Debug)

pub fn parse_pe(data : Bytes) -> PEInfo {
  if data.length() < 64 {
    return {
      signer: "",
      product_name: "",
      company_name: "",
      file_description: "",
      is_dotnet: false,
      subsystem: 0,
    }
  }

  if data[0] != 0x4D || data[1] != 0x5A {
    return {
      signer: "",
      product_name: "",
      company_name: "",
      file_description: "",
      is_dotnet: false,
      subsystem: 0,
    }
  }

  let pe_offset = (data[0x3C].to_int()) |
                  (data[0x3D].to_int() << 8) |
                  (data[0x3E].to_int() << 16) |
                  (data[0x3F].to_int() << 24)

  if pe_offset + 24 >= data.length() {
    return {
      signer: "",
      product_name: "",
      company_name: "",
      file_description: "",
      is_dotnet: false,
      subsystem: 0,
    }
  }

  if data[pe_offset] != 0x50 || data[pe_offset + 1] != 0x45 {
    return {
      signer: "",
      product_name: "",
      company_name: "",
      file_description: "",
      is_dotnet: false,
      subsystem: 0,
    }
  }

  let coff_offset = pe_offset + 4
  let opt_offset = coff_offset + 20

  if opt_offset + 2 >= data.length() {
    return {
      signer: "",
      product_name: "",
      company_name: "",
      file_description: "",
      is_dotnet: false,
      subsystem: 0,
    }
  }

  let magic = data[opt_offset].to_int() | (data[opt_offset + 1].to_int() << 8)

  let subsystem_offset = opt_offset + 68
  let subsystem_val = if subsystem_offset + 2 < data.length() {
    data[subsystem_offset].to_int() | (data[subsystem_offset + 1].to_int() << 8)
  } else {
    0
  }

  let com_descriptor_offset = if magic == 0x20B {
    opt_offset + 208
  } else {
    opt_offset + 192
  }
  let is_dotnet_val = if com_descriptor_offset + 8 < data.length() {
    let com_rva = data[com_descriptor_offset].to_int() |
                  (data[com_descriptor_offset + 1].to_int() << 8) |
                  (data[com_descriptor_offset + 2].to_int() << 16) |
                  (data[com_descriptor_offset + 3].to_int() << 24)
    com_rva != 0
  } else {
    false
  }

  {
    signer: "",
    product_name: "",
    company_name: "",
    file_description: "",
    is_dotnet: is_dotnet_val,
    subsystem: subsystem_val,
  }
}

pub fn parse_pe_file(path : String) -> PEInfo {
  let data = @platform.read_file_bytes(path)
  parse_pe(data)
}