-- ImGuizmo for imgui-luau. Port of https://github.com/CedricGuillemet/ImGuizmo (105e4fde45e4e74aae8973d98750820ef7aca7e2).
-- Usage: local ImGuizmo = require(path.to.ImGuizmo)(require(path.to.ImGui))
return function(G)
    local ImGui, ImVec2, ImVec4 = G.ImGui, G.ImVec2, G.ImVec4
    local ImGuizmo = {}
    local sqrt, abs, sin, cos, tan, atan2 = math.sqrt, math.abs, math.sin, math.cos, math.tan, math.atan2
    local bor = bit32.bor

    -- [Port] OPERATION / MODE enums, same bit values as ImGuizmo.h
    local OPERATION = {
        TRANSLATE_X      = bit32.lshift(1, 0),
        TRANSLATE_Y      = bit32.lshift(1, 1),
        TRANSLATE_Z      = bit32.lshift(1, 2),
        ROTATE_X         = bit32.lshift(1, 3),
        ROTATE_Y         = bit32.lshift(1, 4),
        ROTATE_Z         = bit32.lshift(1, 5),
        ROTATE_SCREEN    = bit32.lshift(1, 6),
        SCALE_X          = bit32.lshift(1, 7),
        SCALE_Y          = bit32.lshift(1, 8),
        SCALE_Z          = bit32.lshift(1, 9),
        BOUNDS           = bit32.lshift(1, 10),
        SCALE_XU         = bit32.lshift(1, 11),
        SCALE_YU         = bit32.lshift(1, 12),
        SCALE_ZU         = bit32.lshift(1, 13),
    }
    OPERATION.TRANSLATE = bor(OPERATION.TRANSLATE_X, OPERATION.TRANSLATE_Y, OPERATION.TRANSLATE_Z)
    OPERATION.ROTATE = bor(OPERATION.ROTATE_X, OPERATION.ROTATE_Y, OPERATION.ROTATE_Z, OPERATION.ROTATE_SCREEN)
    OPERATION.SCALE = bor(OPERATION.SCALE_X, OPERATION.SCALE_Y, OPERATION.SCALE_Z)
    OPERATION.SCALEU = bor(OPERATION.SCALE_XU, OPERATION.SCALE_YU, OPERATION.SCALE_ZU) -- universal
    OPERATION.UNIVERSAL = bor(OPERATION.TRANSLATE, OPERATION.ROTATE, OPERATION.SCALEU)
    ImGuizmo.OPERATION = OPERATION
    ImGuizmo.MODE = { LOCAL = 0, WORLD = 1 }

    local ZPI = 3.14159265358979323846
    local RAD2DEG = (180 / ZPI)
    local DEG2RAD = (ZPI / 180)
    local FLT_EPSILON = 1.192092896e-07

    ---------------------------------------------------------------------------
    -- utility and math

    -- [Port] float* arrays are 1-based Luau arrays: upstream a[i] is a[i + 1]
    local function FPU_MatrixF_x_MatrixF(a, b, r)
        for row = 0, 3 do
            local o = row * 4
            for c = 1, 4 do
                r[o + c] = a[o + 1] * b[c] + a[o + 2] * b[4 + c] + a[o + 3] * b[8 + c] + a[o + 4] * b[12 + c]
            end
        end
    end

    local function Frustum(left, right, bottom, top, znear, zfar, m16, rightHanded)
        if rightHanded == nil then rightHanded = true end
        local temp, temp2, temp3, temp4
        temp = 2 * znear
        temp2 = right - left
        temp3 = top - bottom
        temp4 = zfar - znear
        local sign = 1
        if rightHanded then sign = -1 end
        m16[1] = temp / temp2
        m16[2] = 0
        m16[3] = 0
        m16[4] = 0
        m16[5] = 0
        m16[6] = temp / temp3
        m16[7] = 0
        m16[8] = 0
        m16[9] = (right + left) / temp2
        m16[10] = (top + bottom) / temp3
        m16[11] = sign * (zfar + znear) / temp4
        m16[12] = sign
        m16[13] = 0
        m16[14] = 0
        m16[15] = (-temp * zfar) / temp4
        m16[16] = 0
    end

    local function Perspective(fovyInDegrees, aspectRatio, znear, zfar, m16, rightHanded)
        local ymax, xmax
        ymax = znear * tan(fovyInDegrees * DEG2RAD)
        xmax = ymax * aspectRatio
        Frustum(-xmax, xmax, -ymax, ymax, znear, zfar, m16, rightHanded)
    end

    local function Cross3(a, b, r) -- [Port] upstream float* overload of Cross
        r[1] = a[2] * b[3] - a[3] * b[2]
        r[2] = a[3] * b[1] - a[1] * b[3]
        r[3] = a[1] * b[2] - a[2] * b[1]
    end

    local function Dot3(a, b) -- [Port] upstream float* overload of Dot
        return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
    end

    local function Normalize3(a, r) -- [Port] upstream float* overload of Normalize
        local il = 1 / (sqrt(Dot3(a, a)) + FLT_EPSILON)
        r[1] = a[1] * il
        r[2] = a[2] * il
        r[3] = a[3] * il
    end

    local function LookAt(eye, at, up, m16, rightHanded)
        if rightHanded == nil then rightHanded = true end
        local X, Y, Z, tmp = {}, {}, {}, {}

        if rightHanded then
            tmp[1] = eye[1] - at[1]
            tmp[2] = eye[2] - at[2]
            tmp[3] = eye[3] - at[3]
        else
            tmp[1] = at[1] - eye[1]
            tmp[2] = at[2] - eye[2]
            tmp[3] = at[3] - eye[3]
        end
        Normalize3(tmp, Z)
        Normalize3(up, Y)
        Cross3(Y, Z, tmp)
        Normalize3(tmp, X)
        Cross3(Z, X, tmp)
        Normalize3(tmp, Y)

        m16[1] = X[1]
        m16[2] = Y[1]
        m16[3] = Z[1]
        m16[4] = 0
        m16[5] = X[2]
        m16[6] = Y[2]
        m16[7] = Z[2]
        m16[8] = 0
        m16[9] = X[3]
        m16[10] = Y[3]
        m16[11] = Z[3]
        m16[12] = 0
        m16[13] = -Dot3(X, eye)
        m16[14] = -Dot3(Y, eye)
        m16[15] = -Dot3(Z, eye)
        m16[16] = 1
    end

    -- [Port] Ortho is not in upstream @105e4fd; not ported.

    ---------------------------------------------------------------------------
    -- vec_t  [Port] table {x, y, z, w} with metatable methods/operators
    local vec_t = {}
    vec_t.__index = vec_t

    local function makeVect(_x, _y, _z, _w)
        return setmetatable({ x = _x, y = _y, z = _z or 0, w = _w or 0 }, vec_t)
    end
    vec_t.new = makeVect

    function vec_t:Lerp(v, t)
        self.x += (v.x - self.x) * t
        self.y += (v.y - self.y) * t
        self.z += (v.z - self.z) * t
        self.w += (v.w - self.w) * t
    end

    function vec_t:Set(_x, _y, _z, _w)
        if _y == nil then
            self.x, self.y, self.z, self.w = _x, _x, _x, _x
        else
            self.x, self.y, self.z, self.w = _x, _y, _z or 0, _w or 0
        end
    end

    function vec_t:Copy() return makeVect(self.x, self.y, self.z, self.w) end -- [Port] C++ value copy
    function vec_t:MulScalar(v) self.x *= v; self.y *= v; self.z *= v; self.w *= v; return self end -- [Port] operator *= (float)

    vec_t.__mul = function(a, b)
        if type(b) == "number" then return makeVect(a.x * b, a.y * b, a.z * b, a.w * b) end
        return makeVect(a.x * b.x, a.y * b.y, a.z * b.z, a.w * b.w)
    end
    vec_t.__unm = function(a) return makeVect(-a.x, -a.y, -a.z, -a.w) end
    vec_t.__sub = function(a, b) return makeVect(a.x - b.x, a.y - b.y, a.z - b.z, a.w - b.w) end
    vec_t.__add = function(a, b) return makeVect(a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w) end

    function vec_t:Length() return sqrt(self.x * self.x + self.y * self.y + self.z * self.z) end
    function vec_t:LengthSq() return (self.x * self.x + self.y * self.y + self.z * self.z) end
    function vec_t:Normalize(v)
        if v then self:Set(v.x, v.y, v.z, v.w) end
        local l = self:Length()
        if l <= FLT_EPSILON then l = FLT_EPSILON end
        self:MulScalar(1 / l)
        return self:Copy()
    end
    function vec_t:Abs() return makeVect(abs(self.x), abs(self.y), abs(self.z)) end

    function vec_t:Cross(v1, v2)
        if v2 == nil then v1, v2 = self:Copy(), v1 end
        local x = v1.y * v2.z - v1.z * v2.y
        local y = v1.z * v2.x - v1.x * v2.z
        local z = v1.x * v2.y - v1.y * v2.x
        self.x, self.y, self.z, self.w = x, y, z, 0
    end

    function vec_t:Dot(v) return (self.x * v.x) + (self.y * v.y) + (self.z * v.z) + (self.w * v.w) end
    function vec_t:Dot3(v) return (self.x * v.x) + (self.y * v.y) + (self.z * v.z) end

    -- [Port] m.m[l][c] == m[l * 4 + c + 1]
    function vec_t:Transform(s, matrix)
        if matrix == nil then matrix = s else self:Set(s.x, s.y, s.z, s.w) end
        local m = matrix
        local x, y, z, w = self.x, self.y, self.z, self.w
        self.x = x * m[1] + y * m[5] + z * m[9] + w * m[13]
        self.y = x * m[2] + y * m[6] + z * m[10] + w * m[14]
        self.z = x * m[3] + y * m[7] + z * m[11] + w * m[15]
        self.w = x * m[4] + y * m[8] + z * m[12] + w * m[16]
    end

    function vec_t:TransformPoint(v, matrix)
        if matrix == nil then matrix = v else self:Set(v.x, v.y, v.z, v.w) end
        local m = matrix
        local x, y, z = self.x, self.y, self.z
        self.x = x * m[1] + y * m[5] + z * m[9] + m[13]
        self.y = x * m[2] + y * m[6] + z * m[10] + m[14]
        self.z = x * m[3] + y * m[7] + z * m[11] + m[15]
        self.w = x * m[4] + y * m[8] + z * m[12] + m[16]
    end

    function vec_t:TransformVector(v, matrix)
        if matrix == nil then matrix = v else self:Set(v.x, v.y, v.z, v.w) end
        local m = matrix
        local x, y, z = self.x, self.y, self.z
        self.x = x * m[1] + y * m[5] + z * m[9]
        self.y = x * m[2] + y * m[6] + z * m[10]
        self.z = x * m[3] + y * m[7] + z * m[11]
        self.w = x * m[4] + y * m[8] + z * m[12]
    end

    local function Normalized(v) local res = v:Copy(); res:Normalize(); return res end
    local function Cross(v1, v2) local res = makeVect(0, 0); res:Cross(v1, v2); return res end
    local function Dot(v1, v2) return (v1.x * v2.x) + (v1.y * v2.y) + (v1.z * v2.z) end

    local function BuildPlan(p_point1, p_normal)
        local normal = makeVect(0, 0)
        normal:Normalize(p_normal)
        return makeVect(normal.x, normal.y, normal.z, normal:Dot(p_point1))
    end

    ---------------------------------------------------------------------------
    -- matrix_t  [Port] 16-number 1-based array, same order as upstream m16.
    -- v.right/up/dir/position rows are [1..4]/[5..8]/[9..12]/[13..16]; use GetRow/SetRow.
    local matrix_t = {}
    matrix_t.__index = matrix_t

    function matrix_t.new(src)
        local m = setmetatable({}, matrix_t)
        for i = 1, 16 do m[i] = (src and src[i]) or 0 end
        return m
    end

    function matrix_t:GetRow(r) -- [Port] r: 0 right, 1 up, 2 dir, 3 position
        local o = r * 4
        return makeVect(self[o + 1], self[o + 2], self[o + 3], self[o + 4])
    end
    function matrix_t:SetRow(r, x, y, z, w)
        local o = r * 4
        self[o + 1], self[o + 2], self[o + 3], self[o + 4] = x, y, z, w
    end

    function matrix_t:Translation(_x, _y, _z)
        if type(_x) == "table" then _x, _y, _z = _x.x, _x.y, _x.z end
        self:SetRow(0, 1, 0, 0, 0)
        self:SetRow(1, 0, 1, 0, 0)
        self:SetRow(2, 0, 0, 1, 0)
        self:SetRow(3, _x, _y, _z, 1)
    end

    function matrix_t:Scale(_x, _y, _z)
        if type(_x) == "table" then _x, _y, _z = _x.x, _x.y, _x.z end
        self:SetRow(0, _x, 0, 0, 0)
        self:SetRow(1, 0, _y, 0, 0)
        self:SetRow(2, 0, 0, _z, 0)
        self:SetRow(3, 0, 0, 0, 1)
    end

    matrix_t.__mul = function(a, b)
        local matT = matrix_t.new()
        matT:Multiply(a, b)
        return matT
    end

    function matrix_t:Multiply(m1, m2)
        if m2 == nil then m1, m2 = matrix_t.new(self), m1 end
        FPU_MatrixF_x_MatrixF(m1, m2, self)
    end

    function matrix_t:GetDeterminant()
        local m = self
        return m[1] * m[6] * m[11] + m[2] * m[7] * m[9] + m[3] * m[5] * m[10] -
            m[3] * m[6] * m[9] - m[2] * m[5] * m[11] - m[1] * m[7] * m[10]
    end

    function matrix_t:SetToIdentity()
        self:SetRow(0, 1, 0, 0, 0)
        self:SetRow(1, 0, 1, 0, 0)
        self:SetRow(2, 0, 0, 1, 0)
        self:SetRow(3, 0, 0, 0, 1)
    end

    function matrix_t:Transpose()
        local tmpm = matrix_t.new(self)
        for l = 0, 3 do
            for c = 0, 3 do
                self[l * 4 + c + 1] = tmpm[c * 4 + l + 1]
            end
        end
    end

    function matrix_t:OrthoNormalize()
        for r = 0, 2 do
            local v = self:GetRow(r)
            v:Normalize()
            self:SetRow(r, v.x, v.y, v.z, v.w)
        end
    end

    function matrix_t:Inverse(srcMatrix, affine)
        local det = 0
        local m16 = self
        local S = srcMatrix

        if affine then
            -- [Port] upstream takes the determinant of *this* (not srcMatrix); kept as-is
            det = self:GetDeterminant()
            local s = 1 / det
            local m00 = (S[6] * S[11] - S[7] * S[10]) * s
            local m01 = (S[10] * S[3] - S[11] * S[2]) * s
            local m02 = (S[2] * S[7] - S[3] * S[6]) * s
            local m10 = (S[7] * S[9] - S[5] * S[11]) * s
            local m11 = (S[11] * S[1] - S[9] * S[3]) * s
            local m12 = (S[3] * S[5] - S[1] * S[7]) * s
            local m20 = (S[5] * S[10] - S[6] * S[9]) * s
            local m21 = (S[9] * S[2] - S[10] * S[1]) * s
            local m22 = (S[1] * S[6] - S[2] * S[5]) * s
            m16[1], m16[2], m16[3] = m00, m01, m02
            m16[5], m16[6], m16[7] = m10, m11, m12
            m16[9], m16[10], m16[11] = m20, m21, m22
            m16[13] = -(m00 * S[13] + m10 * S[14] + m20 * S[15])
            m16[14] = -(m01 * S[13] + m11 * S[14] + m21 * S[15])
            m16[15] = -(m02 * S[13] + m12 * S[14] + m22 * S[15])
        else
            -- transpose matrix
            -- [Port] src/tmp kept 0-based so the cofactor formulas match upstream verbatim
            local src = {}
            for i = 0, 3 do
                src[i] = S[i * 4 + 1]
                src[i + 4] = S[i * 4 + 2]
                src[i + 8] = S[i * 4 + 3]
                src[i + 12] = S[i * 4 + 4]
            end

            -- calculate pairs for first 8 elements (cofactors)
            local tmp = {} -- temp array for pairs
            tmp[0] = src[10] * src[15]
            tmp[1] = src[11] * src[14]
            tmp[2] = src[9] * src[15]
            tmp[3] = src[11] * src[13]
            tmp[4] = src[9] * src[14]
            tmp[5] = src[10] * src[13]
            tmp[6] = src[8] * src[15]
            tmp[7] = src[11] * src[12]
            tmp[8] = src[8] * src[14]
            tmp[9] = src[10] * src[12]
            tmp[10] = src[8] * src[13]
            tmp[11] = src[9] * src[12]

            local r = {}
            -- calculate first 8 elements (cofactors)
            r[0] = (tmp[0] * src[5] + tmp[3] * src[6] + tmp[4] * src[7]) - (tmp[1] * src[5] + tmp[2] * src[6] + tmp[5] * src[7])
            r[1] = (tmp[1] * src[4] + tmp[6] * src[6] + tmp[9] * src[7]) - (tmp[0] * src[4] + tmp[7] * src[6] + tmp[8] * src[7])
            r[2] = (tmp[2] * src[4] + tmp[7] * src[5] + tmp[10] * src[7]) - (tmp[3] * src[4] + tmp[6] * src[5] + tmp[11] * src[7])
            r[3] = (tmp[5] * src[4] + tmp[8] * src[5] + tmp[11] * src[6]) - (tmp[4] * src[4] + tmp[9] * src[5] + tmp[10] * src[6])
            r[4] = (tmp[1] * src[1] + tmp[2] * src[2] + tmp[5] * src[3]) - (tmp[0] * src[1] + tmp[3] * src[2] + tmp[4] * src[3])
            r[5] = (tmp[0] * src[0] + tmp[7] * src[2] + tmp[8] * src[3]) - (tmp[1] * src[0] + tmp[6] * src[2] + tmp[9] * src[3])
            r[6] = (tmp[3] * src[0] + tmp[6] * src[1] + tmp[11] * src[3]) - (tmp[2] * src[0] + tmp[7] * src[1] + tmp[10] * src[3])
            r[7] = (tmp[4] * src[0] + tmp[9] * src[1] + tmp[10] * src[2]) - (tmp[5] * src[0] + tmp[8] * src[1] + tmp[11] * src[2])

            -- calculate pairs for second 8 elements (cofactors)
            tmp[0] = src[2] * src[7]
            tmp[1] = src[3] * src[6]
            tmp[2] = src[1] * src[7]
            tmp[3] = src[3] * src[5]
            tmp[4] = src[1] * src[6]
            tmp[5] = src[2] * src[5]
            tmp[6] = src[0] * src[7]
            tmp[7] = src[3] * src[4]
            tmp[8] = src[0] * src[6]
            tmp[9] = src[2] * src[4]
            tmp[10] = src[0] * src[5]
            tmp[11] = src[1] * src[4]

            -- calculate second 8 elements (cofactors)
            r[8] = (tmp[0] * src[13] + tmp[3] * src[14] + tmp[4] * src[15]) - (tmp[1] * src[13] + tmp[2] * src[14] + tmp[5] * src[15])
            r[9] = (tmp[1] * src[12] + tmp[6] * src[14] + tmp[9] * src[15]) - (tmp[0] * src[12] + tmp[7] * src[14] + tmp[8] * src[15])
            r[10] = (tmp[2] * src[12] + tmp[7] * src[13] + tmp[10] * src[15]) - (tmp[3] * src[12] + tmp[6] * src[13] + tmp[11] * src[15])
            r[11] = (tmp[5] * src[12] + tmp[8] * src[13] + tmp[11] * src[14]) - (tmp[4] * src[12] + tmp[9] * src[13] + tmp[10] * src[14])
            r[12] = (tmp[2] * src[10] + tmp[5] * src[11] + tmp[1] * src[9]) - (tmp[4] * src[11] + tmp[0] * src[9] + tmp[3] * src[10])
            r[13] = (tmp[8] * src[11] + tmp[0] * src[8] + tmp[7] * src[10]) - (tmp[6] * src[10] + tmp[9] * src[11] + tmp[1] * src[8])
            r[14] = (tmp[6] * src[9] + tmp[11] * src[11] + tmp[3] * src[8]) - (tmp[10] * src[11] + tmp[2] * src[8] + tmp[7] * src[9])
            r[15] = (tmp[10] * src[10] + tmp[4] * src[8] + tmp[9] * src[9]) - (tmp[8] * src[9] + tmp[11] * src[10] + tmp[5] * src[8])

            -- calculate determinant
            det = src[0] * r[0] + src[1] * r[1] + src[2] * r[2] + src[3] * r[3]

            -- calculate matrix inverse
            local invdet = 1 / det
            for j = 0, 15 do
                m16[j + 1] = r[j] * invdet
            end
        end

        return det
    end

    function matrix_t:RotationAxis(axis, angle)
        local length2 = axis:LengthSq()
        if length2 < FLT_EPSILON then
            self:SetToIdentity()
            return
        end

        local n = axis * (1 / sqrt(length2))
        local s = sin(angle)
        local c = cos(angle)
        local k = 1 - c

        local xx = n.x * n.x * k + c
        local yy = n.y * n.y * k + c
        local zz = n.z * n.z * k + c
        local xy = n.x * n.y * k
        local yz = n.y * n.z * k
        local zx = n.z * n.x * k
        local xs = n.x * s
        local ys = n.y * s
        local zs = n.z * s

        self:SetRow(0, xx, xy + zs, zx - ys, 0)
        self:SetRow(1, xy - zs, yy, yz + xs, 0)
        self:SetRow(2, zx + ys, yz - xs, zz, 0)
        self:SetRow(3, 0, 0, 0, 1)
    end

    local directionUnary = { makeVect(1, 0, 0), makeVect(0, 1, 0), makeVect(0, 0, 1) }

    function ImGuizmo.DecomposeMatrixToComponents(matrix, translation, rotation, scale)
        local mat = matrix_t.new(matrix)

        scale[1] = mat:GetRow(0):Length()
        scale[2] = mat:GetRow(1):Length()
        scale[3] = mat:GetRow(2):Length()

        mat:OrthoNormalize()

        rotation[1] = RAD2DEG * atan2(mat[7], mat[11])
        rotation[2] = RAD2DEG * atan2(-mat[3], sqrt(mat[7] * mat[7] + mat[11] * mat[11]))
        rotation[3] = RAD2DEG * atan2(mat[2], mat[1])

        translation[1] = mat[13]
        translation[2] = mat[14]
        translation[3] = mat[15]
    end

    function ImGuizmo.RecomposeMatrixFromComponents(translation, rotation, scale, matrix)
        local rot = {}
        for i = 1, 3 do
            rot[i] = matrix_t.new()
            rot[i]:RotationAxis(directionUnary[i], rotation[i] * DEG2RAD)
        end

        local mat = rot[1] * rot[2] * rot[3]

        local validScale = {}
        for i = 1, 3 do
            if abs(scale[i]) < FLT_EPSILON then
                validScale[i] = 0.001
            else
                validScale[i] = scale[i]
            end
        end
        for r = 0, 2 do
            for c = 1, 4 do
                mat[r * 4 + c] *= validScale[r + 1]
            end
        end
        mat:SetRow(3, translation[1], translation[2], translation[3], 1)
        -- [Port] write into caller's array in place (upstream aliases float*)
        for i = 1, 16 do matrix[i] = mat[i] end
    end

    -- [Port] internals exposed for later layers and tests
    ImGuizmo._math = {
        vec_t = vec_t, matrix_t = matrix_t, makeVect = makeVect,
        Normalized = Normalized, Cross = Cross, Dot = Dot, BuildPlan = BuildPlan,
        FPU_MatrixF_x_MatrixF = FPU_MatrixF_x_MatrixF,
        Frustum = Frustum, Perspective = Perspective, LookAt = LookAt,
        RAD2DEG = RAD2DEG, DEG2RAD = DEG2RAD, FLT_EPSILON = FLT_EPSILON,
    }
    return ImGuizmo
end
