local mathloader = require("mathloader")

local compile, loadkernel = mathloader.compile, mathloader.loadkernel

src = [[
t[1]=a[1]*b[1]-a[2]*b[2]-a[3]*b[3]-a[4]*b[4]
t[2]=a[2]*b[1]+a[1]*b[2]-a[4]*b[3]+a[3]*b[4]
t[3]=a[3]*b[1]+a[4]*b[2]+a[1]*b[3]-a[2]*b[4]
t[4]=a[4]*b[1]-a[3]*b[2]+a[2]*b[3]+a[1]*b[4]
]]

bitcode = compile(2, src)

do
  local fmt_bitcode = table.clone(bitcode)
  
  for i = 1, #fmt_bitcode do
    fmt_bitcode[i] = string.format("0x%x", fmt_bitcode[i])
  end
  
  print("{ " .. table.concat(fmt_bitcode, ", ") .. " }")
end

qmul = loadkernel(2, bitcode)

do
  local t = table.create(4, 0)
  local a = table.create(4, 0)
  local b = table.create(4, 0)
  a[4], b[4] = 1, 1

  qmul(t,a,b)

  for i = 1,4 do
    t[i] = string.format("%.3f", t[i])
  end

  print(table.concat(t, ","))
end