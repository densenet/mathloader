## mathloader

This module compiles and loads a very compact, specialized subset of Luau for use with generated product kernels.

There are no dependencies.

## example

With an external program, I generate the quaternion algebra
product kernel, by specifying two basis vectors which multiply to
a negative number in a Clifford algebra, obtaining:

```lua
src = [[
t[1]=a[1]*b[1]-a[2]*b[2]-a[3]*b[3]-a[4]*b[4]
t[2]=a[2]*b[1]+a[1]*b[2]-a[4]*b[3]+a[3]*b[4]
t[3]=a[3]*b[1]+a[4]*b[2]+a[1]*b[3]-a[2]*b[4]
t[4]=a[4]*b[1]-a[3]*b[2]+a[2]*b[3]+a[1]*b[4]
]]
```

The above example mostly illustrates the acceptable syntax for mathloader.
In this example, you can think of the indices as follows: `1 -> scalar; 2 -> k; 3 -> j; 4 -> i`

Now, pass through `kcompile(idxwidth, src)`:

```lua
bitcode = kcompile(2, src)
--> { 0x5feb5c21, 0xa9eaf486, 0xcedde278, 0xca66 }
```

The indices and instructions are encoded in the bitcode.
Notice `2`: this describes the amount of bits necessary to describe an index.
For a quaternion, only four unique indices are needed, which is two bits.

Finally, the bitcode can be loaded:

```lua
qmul = kload(2, bitcode)

local t = table.create(4, 0)
local a = table.create(4, 0)
local b = table.create(4, 0)
a[4], b[4] = 1, 1

qmul(t,a,b)

for i = 1,4 do
  t[i] = string.format("%.3f", t[i])
end

print(table.concat(t, ","))
--> -1.000,0.000,0.000,0.000
```