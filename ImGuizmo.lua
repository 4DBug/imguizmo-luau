-- ImGuizmo for imgui-luau. Port of https://github.com/CedricGuillemet/ImGuizmo (105e4fde45e4e74aae8973d98750820ef7aca7e2).
-- Usage: local ImGuizmo = require(path.to.ImGuizmo)(require(path.to.ImGui))
return function(G)
    local ImGui, ImVec2, ImVec4 = G.ImGui, G.ImVec2, G.ImVec4
    local IM_ASSERT, IM_COL32_WHITE = G.IM_ASSERT, G.IM_COL32_WHITE
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

    ---------------------------------------------------------------------------
    -- context / style / translation gizmo
    local band, lshift = bit32.band, bit32.lshift
    local FLT_MAX = 3.402823466e+38

    local function Intersects(lhs, rhs) return band(lhs, rhs) ~= 0 end
    local function Contains(lhs, rhs) return band(lhs, rhs) == rhs end
    local function IsWithin(x, y, z) return (x >= y) and (x <= z) end

    -- [Port] MOVETYPE enum, same values as ImGuizmo.h
    local MT_NONE, MT_MOVE_X, MT_MOVE_Y, MT_MOVE_Z, MT_MOVE_YZ, MT_MOVE_ZX, MT_MOVE_XY, MT_MOVE_SCREEN = 0, 1, 2, 3, 4, 5, 6, 7
    local MT_ROTATE_X, MT_ROTATE_SCREEN, MT_SCALE_X, MT_SCALE_XYZ = 8, 11, 12, 15
    ImGuizmo.MOVETYPE = {
        MT_NONE = 0, MT_MOVE_X = 1, MT_MOVE_Y = 2, MT_MOVE_Z = 3, MT_MOVE_YZ = 4, MT_MOVE_ZX = 5, MT_MOVE_XY = 6, MT_MOVE_SCREEN = 7,
        MT_ROTATE_X = 8, MT_ROTATE_Y = 9, MT_ROTATE_Z = 10, MT_ROTATE_SCREEN = 11,
        MT_SCALE_X = 12, MT_SCALE_Y = 13, MT_SCALE_Z = 14, MT_SCALE_XYZ = 15,
    }

    -- [Port] COLOR enum, 0-based like upstream; Style.Colors is indexed with these values
    local COLOR = {
        DIRECTION_X = 0, DIRECTION_Y = 1, DIRECTION_Z = 2, PLANE_X = 3, PLANE_Y = 4, PLANE_Z = 5,
        SELECTION = 6, INACTIVE = 7, TRANSLATION_LINE = 8, SCALE_LINE = 9, ROTATION_USING_BORDER = 10,
        ROTATION_USING_FILL = 11, HATCHED_AXIS_LINES = 12, TEXT = 13, TEXT_SHADOW = 14, COUNT = 15,
    }
    ImGuizmo.COLOR = COLOR

    local function IsTranslateType(type)
        return type >= MT_MOVE_X and type <= MT_MOVE_SCREEN
    end

    -- Matches MT_MOVE_AB order
    local TRANSLATE_PLANS = { [0] = bor(OPERATION.TRANSLATE_Y, OPERATION.TRANSLATE_Z), bor(OPERATION.TRANSLATE_X, OPERATION.TRANSLATE_Z), bor(OPERATION.TRANSLATE_X, OPERATION.TRANSLATE_Y) }

    local function Style()
        local s = {}
        -- default values
        s.TranslationLineThickness   = 3.0
        s.TranslationLineArrowSize   = 6.0
        s.RotationLineThickness      = 2.0
        s.RotationOuterLineThickness = 3.0
        s.ScaleLineThickness         = 3.0
        s.ScaleLineCircleSize        = 6.0
        s.HatchedAxisLineThickness   = 6.0
        s.CenterCircleSize           = 6.0

        -- initialize default colors
        local Colors = {}
        Colors[COLOR.DIRECTION_X]           = ImVec4(0.666, 0.000, 0.000, 1.000)
        Colors[COLOR.DIRECTION_Y]           = ImVec4(0.000, 0.666, 0.000, 1.000)
        Colors[COLOR.DIRECTION_Z]           = ImVec4(0.000, 0.000, 0.666, 1.000)
        Colors[COLOR.PLANE_X]               = ImVec4(0.666, 0.000, 0.000, 0.380)
        Colors[COLOR.PLANE_Y]               = ImVec4(0.000, 0.666, 0.000, 0.380)
        Colors[COLOR.PLANE_Z]               = ImVec4(0.000, 0.000, 0.666, 0.380)
        Colors[COLOR.SELECTION]             = ImVec4(1.000, 0.500, 0.062, 0.541)
        Colors[COLOR.INACTIVE]              = ImVec4(0.600, 0.600, 0.600, 0.600)
        Colors[COLOR.TRANSLATION_LINE]      = ImVec4(0.666, 0.666, 0.666, 0.666)
        Colors[COLOR.SCALE_LINE]            = ImVec4(0.250, 0.250, 0.250, 1.000)
        Colors[COLOR.ROTATION_USING_BORDER] = ImVec4(1.000, 0.500, 0.062, 1.000)
        Colors[COLOR.ROTATION_USING_FILL]   = ImVec4(1.000, 0.500, 0.062, 0.500)
        Colors[COLOR.HATCHED_AXIS_LINES]    = ImVec4(0.000, 0.000, 0.000, 0.500)
        Colors[COLOR.TEXT]                  = ImVec4(1.000, 1.000, 1.000, 1.000)
        Colors[COLOR.TEXT_SHADOW]           = ImVec4(0.000, 0.000, 0.000, 1.000)
        s.Colors = Colors
        return s
    end

    -- [Port] bool/float [3] arrays are 0-based (indexed by axisIndex)
    local function TripodState()
        return { mBelowAxisLimit = { [0] = false, false, false }, mBelowPlaneLimit = { [0] = false, false, false }, mAxisFactor = { [0] = 1, 1, 1 } }
    end
    local function CopyTripodState(dst, src) -- [Port] C++ struct assignment
        for i = 0, 2 do
            dst.mBelowAxisLimit[i] = src.mBelowAxisLimit[i]
            dst.mBelowPlaneLimit[i] = src.mBelowPlaneLimit[i]
            dst.mAxisFactor[i] = src.mAxisFactor[i]
        end
    end

    -- [Port] ViewManipulateState / mViewManipulateStates not ported yet (ViewManipulate is TODO)
    local gContext = {
        mDrawList = nil,
        mStyle = Style(),

        mMode = ImGuizmo.MODE.LOCAL,
        mViewMat = matrix_t.new(),
        mProjectionMat = matrix_t.new(),
        mModel = matrix_t.new(),
        mModelLocal = matrix_t.new(), -- orthonormalized model
        mModelInverse = matrix_t.new(),
        mModelSource = matrix_t.new(),
        mModelSourceInverse = matrix_t.new(),
        mMVP = matrix_t.new(),
        mMVPLocal = matrix_t.new(), -- MVP with full model matrix whereas mMVP's model matrix might only be translation in case of World space edition
        mViewProjection = matrix_t.new(),

        mModelScaleOrigin = makeVect(0, 0),
        mCameraEye = makeVect(0, 0),
        mCameraRight = makeVect(0, 0),
        mCameraDir = makeVect(0, 0),
        mCameraUp = makeVect(0, 0),
        mRayOrigin = makeVect(0, 0),
        mRayVector = makeVect(0, 0),

        mRadiusSquareCenter = 0,
        mScreenSquareCenter = ImVec2(0, 0),
        mScreenSquareMin = ImVec2(0, 0),
        mScreenSquareMax = ImVec2(0, 0),

        mScreenFactor = 0,
        mRelativeOrigin = makeVect(0, 0),

        mbUsing = false,
        mbUsingViewManipulate = false,
        mbEnable = true,
        mbMouseOver = false,
        mIsViewManipulatorHovered = false,

        -- translation
        mTranslationPlan = makeVect(0, 0),
        mTranslationPlanOrigin = makeVect(0, 0),
        mMatrixOrigin = makeVect(0, 0),
        mTranslationLastDelta = makeVect(0, 0),

        mAxisMask = 0,
        -- Current camera-dependent state and the frozen state of the active drag.
        mTripodState = TripodState(),
        mActiveTripodState = TripodState(),

        mAxisLimit = 0.0025,
        mPlaneLimit = 0.02,

        mbUsingBounds = false,

        --
        mCurrentHandleType = MT_NONE,
        mHoveredHandleType = MT_NONE,

        mX = 0,
        mY = 0,
        mWidth = 0,
        mHeight = 0,
        mXMax = 0,
        mYMax = 0,
        mDisplayRatio = 1,

        mIsOrthographic = false,
        -- check to not have multiple gizmo highlighted at the same time
        mbOverGizmoHotspot = false,
        -- snapshot of mbOverGizmoHotspot from the previous complete frame, so IsOver()
        -- reports hovering over any gizmo regardless of when it is called
        mbOverGizmoHotspotLastFrame = false,

        mAlternativeWindow = nil,
        mIDStack = {}, -- [Port] plain 1-based array of ImGuiID
        mEditingID = -1,
        mOperation = 0,

        mAllowAxisFlip = true,
        mGizmoSizeClipSpace = 0.1,
    }

    local function GetCurrentID()
        local stack = gContext.mIDStack
        if #stack == 0 then
            stack[1] = -1
        end
        return stack[#stack]
    end

    local function GetTripodState()
        if gContext.mbUsing and GetCurrentID() == gContext.mEditingID then
            return gContext.mActiveTripodState
        end
        return gContext.mTripodState
    end

    local directionUnaryV = { [0] = directionUnary[1], directionUnary[2], directionUnary[3] } -- [Port] 0-based view of directionUnary
    local translationInfoMask = { [0] = "X : %5.3f", "Y : %5.3f", "Z : %5.3f",
        "Y : %5.3f Z : %5.3f", "X : %5.3f Z : %5.3f", "X : %5.3f Y : %5.3f",
        "X : %5.3f Y : %5.3f Z : %5.3f" }
    local translationInfoIndex = { [0] = 0,0,0, 1,0,0, 2,0,0, 1,2,0, 0,2,0, 0,1,0, 0,1,2 }
    local quadMin = 0.5
    local quadMax = 0.8
    local quadUV = { [0] = quadMin, quadMin, quadMin, quadMax, quadMax, quadMax, quadMax, quadMin }
    local snapTension = 0.5

    local function vecComp(v, i) -- [Port] vec_t::operator[] (0-based)
        if i == 0 then return v.x elseif i == 1 then return v.y elseif i == 2 then return v.z end
        return v.w
    end

    ---------------------------------------------------------------------------
    --
    local GetMoveType, GetRotateType, GetScaleType

    function ImGuizmo.GetStyle()
        return gContext.mStyle
    end

    local function GetColorU32(idx)
        IM_ASSERT(idx < COLOR.COUNT)
        return ImGui.ColorConvertFloat4ToU32(gContext.mStyle.Colors[idx])
    end

    local function worldToPos(worldPos, mat, position, size)
        if position == nil then position = ImVec2(gContext.mX, gContext.mY) end
        if size == nil then size = ImVec2(gContext.mWidth, gContext.mHeight) end
        local trans = makeVect(0, 0)
        trans:TransformPoint(worldPos, mat)
        if abs(trans.w) < FLT_EPSILON then
            return ImVec2(-FLT_MAX, -FLT_MAX)
        end
        trans:MulScalar(0.5 / trans.w)
        trans = trans + makeVect(0.5, 0.5)
        trans.y = 1 - trans.y
        trans.x *= size.x
        trans.y *= size.y
        trans.x += position.x
        trans.y += position.y
        return ImVec2(trans.x, trans.y)
    end

    -- [Port] returns rayOrigin, rayDir instead of writing references
    local function ComputeCameraRayEx(viewMatrix, projectionMatrix, mousePosition, position, size)
        local mViewProjInverse = matrix_t.new()
        mViewProjInverse:Inverse(viewMatrix * projectionMatrix)

        local mox = ((mousePosition.x - position.x) / size.x) * 2 - 1
        local moy = (1 - ((mousePosition.y - position.y) / size.y)) * 2 - 1

        -- Unproject the mouse at both depth extremes of the clip volume.
        -- A near-zero w means the extreme lies at infinity (an infinite far plane): keep the
        -- homogeneous coordinates in that case instead of dividing by ~0.
        local hA, hB = makeVect(0, 0), makeVect(0, 0)
        hA:Transform(makeVect(mox, moy, 0, 1), mViewProjInverse)
        hB:Transform(makeVect(mox, moy, 1 - FLT_EPSILON, 1), mViewProjInverse)
        local aAtInfinity = abs(hA.w) < FLT_EPSILON
        local bAtInfinity = abs(hB.w) < FLT_EPSILON
        local pointA, pointB = hA, hB
        if not aAtInfinity then pointA = hA * (1 / hA.w) end
        if not bAtInfinity then pointB = hB * (1 / hB.w) end

        -- Camera position. Derived from the view matrix so it is also correct when this is
        -- called for the ViewManipulate cube (which swaps the view/projection matrices).
        local viewInverse = matrix_t.new()
        viewInverse:Inverse(viewMatrix)
        local eye = viewInverse:GetRow(3)

        -- Use the unprojected extreme closest to the camera as the ray origin. (see upstream, issue #423)
        local nearPoint, farPoint, farAtInfinity
        if (pointA - eye):LengthSq() <= (pointB - eye):LengthSq() then
            nearPoint = pointA; farPoint = pointB; farAtInfinity = bAtInfinity
        else
            nearPoint = pointB; farPoint = pointA; farAtInfinity = aAtInfinity
        end

        -- With an infinite far plane the far extreme is unusable, so take the direction from
        -- the camera through the near point (equivalent, and always finite for perspective).
        local rayDir
        if farAtInfinity then
            rayDir = Normalized(nearPoint - eye)
        else
            rayDir = Normalized(farPoint - nearPoint)
        end
        return nearPoint:Copy(), rayDir
    end

    local function ComputeCameraRay(position, size)
        if position == nil then position = ImVec2(gContext.mX, gContext.mY) end
        if size == nil then size = ImVec2(gContext.mWidth, gContext.mHeight) end
        local io = ImGui.GetIO()
        return ComputeCameraRayEx(gContext.mViewMat, gContext.mProjectionMat, io.MousePos, position, size)
    end

    function ImGuizmo.ComputeMouseRay(view, projection, mousePosition, rectPosition, rectSize, rayOrigin, rayDirection)
        local origin, dir = ComputeCameraRayEx(matrix_t.new(view), matrix_t.new(projection), mousePosition, rectPosition, rectSize)
        rayOrigin[1] = origin.x; rayOrigin[2] = origin.y; rayOrigin[3] = origin.z
        rayDirection[1] = dir.x; rayDirection[2] = dir.y; rayDirection[3] = dir.z
    end

    local function GetSegmentLengthClipSpace(start, _end, localCoordinates)
        local startOfSegment = start:Copy()
        local mvp = gContext.mMVP
        if localCoordinates then mvp = gContext.mMVPLocal end
        startOfSegment:TransformPoint(mvp)
        if abs(startOfSegment.w) > FLT_EPSILON then -- check for axis aligned with camera direction
            startOfSegment:MulScalar(1 / startOfSegment.w)
        end

        local endOfSegment = _end:Copy()
        endOfSegment:TransformPoint(mvp)
        if abs(endOfSegment.w) > FLT_EPSILON then -- check for axis aligned with camera direction
            endOfSegment:MulScalar(1 / endOfSegment.w)
        end

        local clipSpaceAxis = endOfSegment - startOfSegment
        if gContext.mDisplayRatio < 1.0 then
            clipSpaceAxis.x *= gContext.mDisplayRatio
        else
            clipSpaceAxis.y /= gContext.mDisplayRatio
        end
        local segmentLengthInClipSpace = sqrt(clipSpaceAxis.x * clipSpaceAxis.x + clipSpaceAxis.y * clipSpaceAxis.y)
        return segmentLengthInClipSpace
    end

    local function GetParallelogram(ptO, ptA, ptB)
        local pts = { ptO:Copy(), ptA:Copy(), ptB:Copy() }
        for i = 1, 3 do
            pts[i]:TransformPoint(gContext.mMVP)
            if abs(pts[i].w) > FLT_EPSILON then -- check for axis aligned with camera direction
                pts[i]:MulScalar(1 / pts[i].w)
            end
        end
        local segA = pts[2] - pts[1]
        local segB = pts[3] - pts[1]
        segA.y /= gContext.mDisplayRatio
        segB.y /= gContext.mDisplayRatio
        local segAOrtho = makeVect(-segA.y, segA.x)
        segAOrtho:Normalize()
        local dt = segAOrtho:Dot3(segB)
        local surface = sqrt(segA.x * segA.x + segA.y * segA.y) * abs(dt)
        return surface
    end

    local function PointOnSegment(point, vertPos1, vertPos2)
        local c = point - vertPos1
        local V = makeVect(0, 0)

        V:Normalize(vertPos2 - vertPos1)
        local d = (vertPos2 - vertPos1):Length()
        local t = V:Dot3(c)

        if t < 0 then
            return vertPos1
        end

        if t > d then
            return vertPos2
        end

        return vertPos1 + V * t
    end

    local function IntersectRayPlane(rOrigin, rVector, plan)
        local numer = plan:Dot3(rOrigin) - plan.w
        local denom = plan:Dot3(rVector)

        if abs(denom) < FLT_EPSILON then -- normal is orthogonal to vector, cant intersect
            return -1.0
        end

        return -(numer / denom)
    end

    local function DistanceToPlane(point, plan)
        return plan:Dot3(point) + plan.w
    end

    local function IsInContextRect(p)
        return IsWithin(p.x, gContext.mX, gContext.mXMax) and IsWithin(p.y, gContext.mY, gContext.mYMax)
    end

    local function IsHoveringWindow()
        local g = ImGui.GetCurrentContext()
        local window = ImGui.FindWindowByName(gContext.mDrawList._OwnerName)
        if g.HoveredWindow == window then -- Mouse hovering drawlist window
            return true
        end
        if gContext.mAlternativeWindow ~= nil and g.HoveredWindow == gContext.mAlternativeWindow then
            return true
        end
        if g.HoveredWindow ~= nil then -- Any other window is hovered
            return false
        end
        if ImGui.IsMouseHoveringRect(window.InnerRect.Min, window.InnerRect.Max, false) then -- Hovering drawlist window rect, while no other window is hovered (for _NoInputs windows)
            return true
        end
        return false
    end

    function ImGuizmo.SetRect(x, y, width, height)
        gContext.mX = x
        gContext.mY = y
        gContext.mWidth = width
        gContext.mHeight = height
        gContext.mXMax = gContext.mX + gContext.mWidth
        gContext.mYMax = gContext.mY + gContext.mHeight
        gContext.mDisplayRatio = width / height
    end

    function ImGuizmo.SetOrthographic(isOrthographic)
        gContext.mIsOrthographic = isOrthographic
    end

    function ImGuizmo.SetDrawlist(drawlist)
        gContext.mDrawList = drawlist or ImGui.GetWindowDrawList()
    end

    function ImGuizmo.SetImGuiContext(ctx)
        ImGui.SetCurrentContext(ctx)
    end

    function ImGuizmo.BeginFrame()
        local WF = G.ImGuiWindowFlags
        local flags = bor(WF.NoTitleBar, WF.NoResize, WF.NoScrollbar, WF.NoInputs, WF.NoSavedSettings, WF.NoFocusOnAppearing, WF.NoBringToFrontOnFocus)

        -- [Port] IMGUI_HAS_VIEWPORT path (core is the docking branch)
        ImGui.SetNextWindowSize(ImGui.GetMainViewport().Size)
        ImGui.SetNextWindowPos(ImGui.GetMainViewport().Pos)

        ImGui.PushStyleColor(G.ImGuiCol.WindowBg, 0)
        ImGui.PushStyleColor(G.ImGuiCol.Border, 0)
        ImGui.PushStyleVar(G.ImGuiStyleVar.WindowRounding, 0.0)

        ImGui.Begin("gizmo", nil, flags)
        gContext.mDrawList = ImGui.GetWindowDrawList()
        gContext.mbOverGizmoHotspotLastFrame = gContext.mbOverGizmoHotspot
        gContext.mbOverGizmoHotspot = false
        -- view manipulate flags accumulate across every ViewManipulate call of the frame
        gContext.mbUsingViewManipulate = false
        gContext.mIsViewManipulatorHovered = false
        ImGui.End()
        ImGui.PopStyleVar()
        ImGui.PopStyleColor(2)
    end

    function ImGuizmo.IsUsing()
        return (gContext.mbUsing and (GetCurrentID() == gContext.mEditingID)) or gContext.mbUsingBounds
    end

    function ImGuizmo.IsUsingViewManipulate()
        return gContext.mbUsingViewManipulate
    end

    function ImGuizmo.IsViewManipulateHovered()
        return gContext.mIsViewManipulatorHovered
    end

    function ImGuizmo.IsUsingAny()
        return gContext.mbUsing or gContext.mbUsingBounds
    end

    -- [Port] overloads merged: IsOver(), IsOver(op), IsOver(position, pixelRadius)
    function ImGuizmo.IsOver(op, pixelRadius)
        if type(op) == "table" then
            local io = ImGui.GetIO()
            local p = worldToPos(makeVect(op[1], op[2], op[3], 0), gContext.mViewProjection) - io.MousePos
            local radius = sqrt(p.x * p.x + p.y * p.y)
            return radius < pixelRadius
        end
        if op == nil then
            -- mbOverGizmoHotspotLastFrame is accumulated across every Manipulate call of the
            -- previous frame, so this reports hovering over any gizmo instead of only the last one.
            -- IsUsingAny() (not IsUsing()) is used so an active drag is detected even when IsOver()
            -- is queried outside the PushID scope of the gizmo being manipulated.
            return gContext.mbOverGizmoHotspotLastFrame or ImGuizmo.IsUsingAny()
        end
        if ImGuizmo.IsUsing() then
            return true
        end
        if Intersects(op, bor(OPERATION.SCALE, OPERATION.SCALEU)) and GetScaleType(op) ~= MT_NONE then
            return true
        end
        if Intersects(op, OPERATION.ROTATE) and GetRotateType(op) ~= MT_NONE then
            return true
        end
        if Intersects(op, OPERATION.TRANSLATE) and GetMoveType(op, nil) ~= MT_NONE then
            return true
        end
        return false
    end

    function ImGuizmo.GetActiveHandleType()
        if not gContext.mbUsing or GetCurrentID() ~= gContext.mEditingID then
            return MT_NONE
        end
        return gContext.mCurrentHandleType
    end

    function ImGuizmo.GetHoveredHandleType()
        return gContext.mHoveredHandleType
    end

    ImGuizmo.GetActiveMoveType = ImGuizmo.GetActiveHandleType
    ImGuizmo.GetHoveredMoveType = ImGuizmo.GetHoveredHandleType

    function ImGuizmo.Enable(enable)
        gContext.mbEnable = enable
        if not enable then
            -- Only cancel an ongoing interaction when the gizmo being disabled is the one
            -- currently edited. Otherwise disabling one gizmo would wipe the shared using
            -- state and break another gizmo that is still enabled/being manipulated.
            if not gContext.mbUsing or GetCurrentID() == gContext.mEditingID then
                gContext.mbUsing = false
                gContext.mbUsingBounds = false
                gContext.mCurrentHandleType = MT_NONE
                gContext.mHoveredHandleType = MT_NONE
            end
        end
    end

    local function ComputeContext(view, projection, matrix, mode)
        gContext.mMode = mode
        gContext.mViewMat = matrix_t.new(view)
        gContext.mProjectionMat = matrix_t.new(projection)
        gContext.mbMouseOver = IsHoveringWindow()

        gContext.mModelLocal = matrix_t.new(matrix)
        gContext.mModelLocal:OrthoNormalize()

        if mode == ImGuizmo.MODE.LOCAL then
            gContext.mModel = matrix_t.new(gContext.mModelLocal)
        else
            gContext.mModel:Translation(matrix[13], matrix[14], matrix[15])
        end
        gContext.mModelSource = matrix_t.new(matrix)
        local ms = gContext.mModelSource
        gContext.mModelScaleOrigin:Set(ms:GetRow(0):Length(), ms:GetRow(1):Length(), ms:GetRow(2):Length())

        gContext.mModelInverse:Inverse(gContext.mModel)
        gContext.mModelSourceInverse:Inverse(gContext.mModelSource)
        gContext.mViewProjection = gContext.mViewMat * gContext.mProjectionMat
        gContext.mMVP = gContext.mModel * gContext.mViewProjection
        gContext.mMVPLocal = gContext.mModelLocal * gContext.mViewProjection

        local viewInverse = matrix_t.new()
        viewInverse:Inverse(gContext.mViewMat)
        gContext.mCameraDir = viewInverse:GetRow(2)
        gContext.mCameraEye = viewInverse:GetRow(3)
        gContext.mCameraRight = viewInverse:GetRow(0)
        gContext.mCameraUp = viewInverse:GetRow(1)

        -- compute scale from the size of camera right vector projected on screen at the matrix position
        -- [Port] upstream's unused pointRight computation dropped
        local rightViewInverse = viewInverse:GetRow(0)
        rightViewInverse:TransformVector(gContext.mModelInverse)
        local rightLength = GetSegmentLengthClipSpace(makeVect(0, 0), rightViewInverse)
        gContext.mScreenFactor = gContext.mGizmoSizeClipSpace / rightLength

        local centerSSpace = worldToPos(makeVect(0, 0), gContext.mMVP)
        gContext.mScreenSquareCenter = centerSSpace
        gContext.mScreenSquareMin = ImVec2(centerSSpace.x - 10, centerSSpace.y - 10)
        gContext.mScreenSquareMax = ImVec2(centerSSpace.x + 10, centerSSpace.y + 10)

        gContext.mRayOrigin, gContext.mRayVector = ComputeCameraRay()
    end

    -- [Port] colors is a 0-based table (colors[0..6])
    local function ComputeColors(colors, type, operation)
        if gContext.mbEnable then
            local selectionColor = GetColorU32(COLOR.SELECTION)

            if operation == OPERATION.TRANSLATE then
                if type == MT_MOVE_SCREEN then colors[0] = selectionColor else colors[0] = IM_COL32_WHITE end
                for i = 0, 2 do
                    if type == MT_MOVE_X + i then colors[i + 1] = selectionColor else colors[i + 1] = GetColorU32(COLOR.DIRECTION_X + i) end
                    if type == MT_MOVE_YZ + i then colors[i + 4] = selectionColor else colors[i + 4] = GetColorU32(COLOR.PLANE_X + i) end
                    if type == MT_MOVE_SCREEN then colors[i + 4] = selectionColor end
                end
            elseif operation == OPERATION.ROTATE then
                if type == MT_ROTATE_SCREEN then colors[0] = selectionColor else colors[0] = IM_COL32_WHITE end
                for i = 0, 2 do
                    if type == MT_ROTATE_X + i then colors[i + 1] = selectionColor else colors[i + 1] = GetColorU32(COLOR.DIRECTION_X + i) end
                end
            elseif operation == OPERATION.SCALEU or operation == OPERATION.SCALE then
                if type == MT_SCALE_XYZ then colors[0] = selectionColor else colors[0] = IM_COL32_WHITE end
                for i = 0, 2 do
                    if type == MT_SCALE_X + i then colors[i + 1] = selectionColor else colors[i + 1] = GetColorU32(COLOR.DIRECTION_X + i) end
                end
            end
            -- note: this internal function is only called with three possible values for operation
        else
            local inactiveColor = GetColorU32(COLOR.INACTIVE)
            for i = 0, 6 do
                colors[i] = inactiveColor
            end
        end
    end

    -- [Port] returns dirAxis, dirPlaneX, dirPlaneY, belowAxisLimit, belowPlaneLimit
    local function ComputeTripodAxisAndVisibility(axisIndex, localCoordinates)
        local dirAxis = directionUnaryV[axisIndex]:Copy()
        local dirPlaneX = directionUnaryV[(axisIndex + 1) % 3]:Copy()
        local dirPlaneY = directionUnaryV[(axisIndex + 2) % 3]:Copy()
        local belowAxisLimit, belowPlaneLimit
        local tripodState = GetTripodState()
        local axisBit = lshift(1, axisIndex)

        if gContext.mbUsing and (GetCurrentID() == gContext.mEditingID) then
            -- when using, use stored factors so the gizmo doesn't flip when we translate

            -- Apply axis mask to axes and planes
            belowAxisLimit = tripodState.mBelowAxisLimit[axisIndex] and band(axisBit, gContext.mAxisMask) == 0
            belowPlaneLimit = tripodState.mBelowPlaneLimit[axisIndex] and ((axisBit == gContext.mAxisMask) or gContext.mAxisMask == 0)

            dirAxis:MulScalar(tripodState.mAxisFactor[axisIndex])
            dirPlaneX:MulScalar(tripodState.mAxisFactor[(axisIndex + 1) % 3])
            dirPlaneY:MulScalar(tripodState.mAxisFactor[(axisIndex + 2) % 3])
        else
            -- new method
            local zero = makeVect(0, 0, 0)
            local lenDir = GetSegmentLengthClipSpace(zero, dirAxis, localCoordinates)
            local lenDirMinus = GetSegmentLengthClipSpace(zero, -dirAxis, localCoordinates)

            local lenDirPlaneX = GetSegmentLengthClipSpace(zero, dirPlaneX, localCoordinates)
            local lenDirMinusPlaneX = GetSegmentLengthClipSpace(zero, -dirPlaneX, localCoordinates)

            local lenDirPlaneY = GetSegmentLengthClipSpace(zero, dirPlaneY, localCoordinates)
            local lenDirMinusPlaneY = GetSegmentLengthClipSpace(zero, -dirPlaneY, localCoordinates)

            -- For readability
            local allowFlip = gContext.mAllowAxisFlip
            local mulAxis, mulAxisX, mulAxisY = 1, 1, 1
            if allowFlip and lenDir < lenDirMinus and abs(lenDir - lenDirMinus) > FLT_EPSILON then mulAxis = -1 end
            if allowFlip and lenDirPlaneX < lenDirMinusPlaneX and abs(lenDirPlaneX - lenDirMinusPlaneX) > FLT_EPSILON then mulAxisX = -1 end
            if allowFlip and lenDirPlaneY < lenDirMinusPlaneY and abs(lenDirPlaneY - lenDirMinusPlaneY) > FLT_EPSILON then mulAxisY = -1 end
            dirAxis:MulScalar(mulAxis)
            dirPlaneX:MulScalar(mulAxisX)
            dirPlaneY:MulScalar(mulAxisY)

            -- for axis
            local axisLengthInClipSpace = GetSegmentLengthClipSpace(zero, dirAxis * gContext.mScreenFactor, localCoordinates)

            local paraSurf = GetParallelogram(zero, dirPlaneX * gContext.mScreenFactor, dirPlaneY * gContext.mScreenFactor)
            -- Apply axis mask to axes and planes
            belowPlaneLimit = (paraSurf > gContext.mAxisLimit) and ((axisBit == gContext.mAxisMask) or gContext.mAxisMask == 0)
            belowAxisLimit = (axisLengthInClipSpace > gContext.mPlaneLimit) and band(axisBit, gContext.mAxisMask) == 0

            -- and store values
            tripodState.mAxisFactor[axisIndex] = mulAxis
            tripodState.mAxisFactor[(axisIndex + 1) % 3] = mulAxisX
            tripodState.mAxisFactor[(axisIndex + 2) % 3] = mulAxisY
            tripodState.mBelowAxisLimit[axisIndex] = belowAxisLimit
            tripodState.mBelowPlaneLimit[axisIndex] = belowPlaneLimit
        end
        return dirAxis, dirPlaneX, dirPlaneY, belowAxisLimit, belowPlaneLimit
    end

    -- [Port] float* overload returns the snapped value
    local function ComputeSnap(value, snap)
        if snap <= FLT_EPSILON then
            return value
        end

        local modulo = math.fmod(value, snap)
        local moduloRatio = abs(modulo) / snap
        if moduloRatio < snapTension then
            value -= modulo
        elseif moduloRatio > (1 - snapTension) then
            local sgn = 1
            if value < 0 then sgn = -1 end
            value = value - modulo + snap * sgn
        end
        return value
    end
    local function ComputeSnapV(value, snap) -- [Port] vec_t overload, snap is a 1-based float[3]
        value.x = ComputeSnap(value.x, snap[1])
        value.y = ComputeSnap(value.y, snap[2])
        value.z = ComputeSnap(value.z, snap[3])
    end

    local function DrawHatchedAxis(axis)
        if gContext.mStyle.HatchedAxisLineThickness <= 0.0 then
            return
        end

        for j = 1, 9 do
            local baseSSpace2 = worldToPos(axis * (0.05 * (j * 2) * gContext.mScreenFactor), gContext.mMVP)
            local worldDirSSpace2 = worldToPos(axis * (0.05 * (j * 2 + 1) * gContext.mScreenFactor), gContext.mMVP)
            gContext.mDrawList:AddLine(baseSSpace2, worldDirSSpace2, GetColorU32(COLOR.HATCHED_AXIS_LINES), gContext.mStyle.HatchedAxisLineThickness)
        end
    end

    local function DrawRotationGizmo(op, type) end -- [Port] TODO
    local function DrawScaleGizmo(op, type) end -- [Port] TODO
    local function DrawScaleUniveralGizmo(op, type) end -- [Port] TODO

    local function DrawTranslationGizmo(op, type)
        local drawList = gContext.mDrawList
        if not drawList then
            return
        end

        if not Intersects(op, OPERATION.TRANSLATE) then
            return
        end

        -- colors
        local colors = {}
        ComputeColors(colors, type, OPERATION.TRANSLATE)

        local origin = worldToPos(gContext.mModel:GetRow(3), gContext.mViewProjection)

        -- draw
        for i = 0, 2 do
            local dirAxis, dirPlaneX, dirPlaneY, belowAxisLimit, belowPlaneLimit = ComputeTripodAxisAndVisibility(i)

            if not gContext.mbUsing or (gContext.mbUsing and type == MT_MOVE_X + i) then
                -- draw axis
                if belowAxisLimit and Intersects(op, lshift(OPERATION.TRANSLATE_X, i)) then
                    local baseSSpace = worldToPos(dirAxis * (0.1 * gContext.mScreenFactor), gContext.mMVP)
                    local worldDirSSpace = worldToPos(dirAxis * gContext.mScreenFactor, gContext.mMVP)

                    drawList:AddLine(baseSSpace, worldDirSSpace, colors[i + 1], gContext.mStyle.TranslationLineThickness)

                    -- Arrow head begin
                    local dx, dy = origin.x - worldDirSSpace.x, origin.y - worldDirSSpace.y

                    local d = sqrt(dx * dx + dy * dy)
                    dx /= d; dy /= d -- Normalize
                    dx *= gContext.mStyle.TranslationLineArrowSize
                    dy *= gContext.mStyle.TranslationLineArrowSize

                    local ox, oy = dy, -dx -- Perpendicular vector
                    local ax, ay = worldDirSSpace.x + dx, worldDirSSpace.y + dy
                    drawList:AddTriangleFilled(ImVec2(worldDirSSpace.x - dx, worldDirSSpace.y - dy), ImVec2(ax + ox, ay + oy), ImVec2(ax - ox, ay - oy), colors[i + 1])
                    -- Arrow head end

                    if GetTripodState().mAxisFactor[i] < 0 then
                        DrawHatchedAxis(dirAxis)
                    end
                end
            end
            -- draw plane
            if not gContext.mbUsing or (gContext.mbUsing and type == MT_MOVE_YZ + i) then
                if belowPlaneLimit and Contains(op, TRANSLATE_PLANS[i]) then
                    local screenQuadPts = {}
                    for j = 0, 3 do
                        local cornerWorldPos = (dirPlaneX * quadUV[j * 2] + dirPlaneY * quadUV[j * 2 + 1]) * gContext.mScreenFactor
                        screenQuadPts[j + 1] = worldToPos(cornerWorldPos, gContext.mMVP)
                    end
                    -- [Port] core has no public AddPolyline; _AddPolyline with FLT_MAX inner offset as AddQuad does
                    drawList:_AddPolyline(screenQuadPts, 4, GetColorU32(COLOR.DIRECTION_X + i), 1.0, G.ImDrawFlags.Closed, FLT_MAX)
                    drawList:AddConvexPolyFilled(screenQuadPts, 4, colors[i + 4])
                end
            end
        end

        drawList:AddCircleFilled(gContext.mScreenSquareCenter, gContext.mStyle.CenterCircleSize, colors[0], 32)

        if gContext.mbUsing and (GetCurrentID() == gContext.mEditingID) and IsTranslateType(type) then
            local translationLineColor = GetColorU32(COLOR.TRANSLATION_LINE)

            local sourcePosOnScreen = worldToPos(gContext.mMatrixOrigin, gContext.mViewProjection)
            local destinationPosOnScreen = worldToPos(gContext.mModel:GetRow(3), gContext.mViewProjection)
            local dif = makeVect(destinationPosOnScreen.x - sourcePosOnScreen.x, destinationPosOnScreen.y - sourcePosOnScreen.y, 0, 0)
            dif:Normalize()
            dif:MulScalar(5)
            drawList:AddCircle(sourcePosOnScreen, 6, translationLineColor)
            drawList:AddCircle(destinationPosOnScreen, 6, translationLineColor)
            drawList:AddLine(ImVec2(sourcePosOnScreen.x + dif.x, sourcePosOnScreen.y + dif.y), ImVec2(destinationPosOnScreen.x - dif.x, destinationPosOnScreen.y - dif.y), translationLineColor, 2)

            local deltaInfo = gContext.mModel:GetRow(3) - gContext.mMatrixOrigin
            local componentInfoIndex = (type - MT_MOVE_X) * 3
            local tmps = string.format(translationInfoMask[type - MT_MOVE_X], vecComp(deltaInfo, translationInfoIndex[componentInfoIndex]), vecComp(deltaInfo, translationInfoIndex[componentInfoIndex + 1]), vecComp(deltaInfo, translationInfoIndex[componentInfoIndex + 2]))
            drawList:AddText(ImVec2(destinationPosOnScreen.x + 15, destinationPosOnScreen.y + 15), GetColorU32(COLOR.TEXT_SHADOW), tmps)
            drawList:AddText(ImVec2(destinationPosOnScreen.x + 14, destinationPosOnScreen.y + 14), GetColorU32(COLOR.TEXT), tmps)
        end
    end

    local function CanActivate()
        if ImGui.IsMouseClicked(0) and not ImGui.IsAnyItemHovered() and not ImGui.IsAnyItemActive() then
            return true
        end
        return false
    end

    local function HandleAndDrawLocalBounds(bounds, matrix, snapValues, operation) return false end -- [Port] TODO
    function GetScaleType(op) return MT_NONE end -- [Port] TODO
    function GetRotateType(op) return MT_NONE end -- [Port] TODO

    -- [Port] gizmoHitProportion: returns type, hitProportion instead of writing through a pointer
    function GetMoveType(op, wantHitProportion)
        if not Intersects(op, OPERATION.TRANSLATE) or gContext.mbUsing or not gContext.mbMouseOver then
            return MT_NONE
        end

        local isNoAxesMasked = gContext.mAxisMask == 0
        local isMultipleAxesMasked = band(gContext.mAxisMask, gContext.mAxisMask - 1) ~= 0

        local io = ImGui.GetIO()
        local type = MT_NONE
        local gizmoHitProportion = nil

        -- screen
        if io.MousePos.x >= gContext.mScreenSquareMin.x and io.MousePos.x <= gContext.mScreenSquareMax.x and
            io.MousePos.y >= gContext.mScreenSquareMin.y and io.MousePos.y <= gContext.mScreenSquareMax.y and
            Contains(op, OPERATION.TRANSLATE) then
            type = MT_MOVE_SCREEN
        end

        local screenCoord = makeVect(io.MousePos.x - gContext.mX, io.MousePos.y - gContext.mY)
        local modelPos = gContext.mModel:GetRow(3)

        -- compute
        local i = 0
        while i < 3 and type == MT_NONE do
            local isAxisMasked = band(lshift(1, i), gContext.mAxisMask) ~= 0
            local dirAxis, dirPlaneX, dirPlaneY, _belowAxisLimit, belowPlaneLimit = ComputeTripodAxisAndVisibility(i)
            dirAxis:TransformVector(gContext.mModel)
            dirPlaneX:TransformVector(gContext.mModel)
            dirPlaneY:TransformVector(gContext.mModel)

            local len = IntersectRayPlane(gContext.mRayOrigin, gContext.mRayVector, BuildPlan(modelPos, dirAxis))
            local posOnPlan = gContext.mRayOrigin + gContext.mRayVector * len

            local axisStartOnScreen = worldToPos(modelPos + dirAxis * (gContext.mScreenFactor * 0.1), gContext.mViewProjection)
            local axisEndOnScreen = worldToPos(modelPos + dirAxis * gContext.mScreenFactor, gContext.mViewProjection)

            local closestPointOnAxis = PointOnSegment(screenCoord, makeVect(axisStartOnScreen.x - gContext.mX, axisStartOnScreen.y - gContext.mY), makeVect(axisEndOnScreen.x - gContext.mX, axisEndOnScreen.y - gContext.mY))
            if (closestPointOnAxis - screenCoord):Length() < 12 and Intersects(op, lshift(OPERATION.TRANSLATE_X, i)) then -- pixel size
                if isAxisMasked then
                    break
                end
                type = MT_MOVE_X + i
            end

            local dx = dirPlaneX:Dot3((posOnPlan - modelPos) * (1 / gContext.mScreenFactor))
            local dy = dirPlaneY:Dot3((posOnPlan - modelPos) * (1 / gContext.mScreenFactor))
            if belowPlaneLimit and dx >= quadUV[0] and dx <= quadUV[4] and dy >= quadUV[1] and dy <= quadUV[3] and Contains(op, TRANSLATE_PLANS[i]) then
                if (not isAxisMasked or isMultipleAxesMasked) and not isNoAxesMasked then
                    break
                end
                type = MT_MOVE_YZ + i
            end

            if wantHitProportion then
                gizmoHitProportion = makeVect(dx, dy, 0)
            end
            i += 1
        end
        return type, gizmoHitProportion
    end

    -- [Port] returns modified, type (C++ MOVETYPE& type)
    local function HandleTranslation(matrix, deltaMatrix, op, type, snap)
        if not Intersects(op, OPERATION.TRANSLATE) or type ~= MT_NONE then
            return false, type
        end
        local applyRotationLocaly = gContext.mMode == ImGuizmo.MODE.LOCAL or gContext.mCurrentHandleType == MT_MOVE_SCREEN
        local modified = false

        -- move
        if gContext.mbUsing and (GetCurrentID() == gContext.mEditingID) and IsTranslateType(gContext.mCurrentHandleType) then
            ImGui.SetNextFrameWantCaptureMouse(true)
            local signedLength = IntersectRayPlane(gContext.mRayOrigin, gContext.mRayVector, gContext.mTranslationPlan)
            local len = abs(signedLength) -- near plan
            local newPos = gContext.mRayOrigin + gContext.mRayVector * len

            -- compute delta
            local newOrigin = newPos - gContext.mRelativeOrigin * gContext.mScreenFactor
            local delta = newOrigin - gContext.mModel:GetRow(3)

            -- 1 axis constraint
            if gContext.mCurrentHandleType >= MT_MOVE_X and gContext.mCurrentHandleType <= MT_MOVE_Z then
                local axisIndex = gContext.mCurrentHandleType - MT_MOVE_X
                local axisValue = gContext.mModel:GetRow(axisIndex)
                local lengthOnAxis = Dot(axisValue, delta)
                delta = axisValue * lengthOnAxis
            end

            -- snap
            if snap then
                local cumulativeDelta = gContext.mModel:GetRow(3) + delta - gContext.mMatrixOrigin
                if applyRotationLocaly then
                    local modelSourceNormalized = matrix_t.new(gContext.mModelSource)
                    modelSourceNormalized:OrthoNormalize()
                    local modelSourceNormalizedInverse = matrix_t.new()
                    modelSourceNormalizedInverse:Inverse(modelSourceNormalized)
                    cumulativeDelta:TransformVector(modelSourceNormalizedInverse)
                    ComputeSnapV(cumulativeDelta, snap)
                    cumulativeDelta:TransformVector(modelSourceNormalized)
                else
                    ComputeSnapV(cumulativeDelta, snap)
                end
                delta = gContext.mMatrixOrigin + cumulativeDelta - gContext.mModel:GetRow(3)
            end

            local last = gContext.mTranslationLastDelta
            if delta.x ~= last.x or delta.y ~= last.y or delta.z ~= last.z or delta.w ~= last.w then
                modified = true
            end
            gContext.mTranslationLastDelta = delta

            -- compute matrix & delta
            local deltaMatrixTranslation = matrix_t.new()
            deltaMatrixTranslation:Translation(delta)
            if deltaMatrix then
                for k = 1, 16 do deltaMatrix[k] = deltaMatrixTranslation[k] end
            end

            local res = gContext.mModelSource * deltaMatrixTranslation
            for k = 1, 16 do matrix[k] = res[k] end -- [Port] write into caller's array in place

            if not ImGui.IsMouseDown(0) then -- [Port] io.MouseDown[0]
                gContext.mbUsing = false
            end

            type = gContext.mCurrentHandleType
        else
            -- find new possible way to move
            if gContext.mbOverGizmoHotspot then
                type = MT_NONE
            else
                type = GetMoveType(op, true)
            end
            gContext.mbOverGizmoHotspot = gContext.mbOverGizmoHotspot or type ~= MT_NONE
            if type ~= MT_NONE then
                ImGui.SetNextFrameWantCaptureMouse(true)
            end
            if CanActivate() and type ~= MT_NONE then
                CopyTripodState(gContext.mActiveTripodState, gContext.mTripodState)
                gContext.mbUsing = true
                gContext.mEditingID = GetCurrentID()
                gContext.mCurrentHandleType = type
                local m = gContext.mModel
                local movePlanNormal = { m:GetRow(0), m:GetRow(1), m:GetRow(2),
                    m:GetRow(0), m:GetRow(1), m:GetRow(2),
                    -gContext.mCameraDir }

                local cameraToModelNormalized = Normalized(m:GetRow(3) - gContext.mCameraEye)
                for k = 1, 3 do
                    local orthoVector = Cross(movePlanNormal[k], cameraToModelNormalized)
                    movePlanNormal[k]:Cross(orthoVector)
                    movePlanNormal[k]:Normalize()
                end
                -- pickup plan
                gContext.mTranslationPlan = BuildPlan(m:GetRow(3), movePlanNormal[type - MT_MOVE_X + 1])
                local len = IntersectRayPlane(gContext.mRayOrigin, gContext.mRayVector, gContext.mTranslationPlan)
                gContext.mTranslationPlanOrigin = gContext.mRayOrigin + gContext.mRayVector * len
                gContext.mMatrixOrigin = m:GetRow(3)

                gContext.mRelativeOrigin = (gContext.mTranslationPlanOrigin - m:GetRow(3)) * (1 / gContext.mScreenFactor)
            end
        end
        return modified, type
    end

    local function HandleScale(matrix, deltaMatrix, op, type, snap) return false, type end -- [Port] TODO
    local function HandleRotation(matrix, deltaMatrix, op, type, snap) return false, type end -- [Port] TODO

    function ImGuizmo.SetAlternativeWindow(window)
        gContext.mAlternativeWindow = window
    end

    function ImGuizmo.SetID(id)
        local stack = gContext.mIDStack
        if #stack == 0 then
            stack[1] = -1
        end
        stack[#stack] = id
    end

    -- [Port] overloads merged: string (optional str_end exclusive 1-based), number (int), other (pointer -> tostring hash)
    function ImGuizmo.GetID(str, str_end)
        local seed = GetCurrentID()
        if type(str) == "number" then
            return G.ImHashData(str, -1, seed)
        end
        if type(str) ~= "string" then
            str = tostring(str)
        end
        if str_end then
            return G.ImHashStr(str, str_end - 1, seed)
        end
        return G.ImHashStr(str, nil, seed)
    end

    function ImGuizmo.PushID(str_id, str_id_end)
        local id = ImGuizmo.GetID(str_id, str_id_end)
        table.insert(gContext.mIDStack, id)
    end

    function ImGuizmo.PopID()
        IM_ASSERT(#gContext.mIDStack > 1) -- Too many PopID(), or could be popping in a wrong/different window?
        table.remove(gContext.mIDStack)
    end

    function ImGuizmo.AllowAxisFlip(value)
        gContext.mAllowAxisFlip = value
    end

    function ImGuizmo.SetAxisLimit(value)
        gContext.mAxisLimit = value
    end

    function ImGuizmo.SetAxisMask(x, y, z)
        local m = 0
        if x then m += 1 end
        if y then m += 2 end
        if z then m += 4 end
        gContext.mAxisMask = m
    end

    function ImGuizmo.SetPlaneLimit(value)
        gContext.mPlaneLimit = value
    end

    -- [Port] matrix/deltaMatrix are mutated in place; snap/localBounds/boundsSnap optional 1-based arrays
    function ImGuizmo.Manipulate(view, projection, operation, mode, matrix, deltaMatrix, snap, localBounds, boundsSnap)
        gContext.mDrawList:PushClipRect(ImVec2(gContext.mX, gContext.mY), ImVec2(gContext.mX + gContext.mWidth, gContext.mY + gContext.mHeight), false)

        -- Scale is always local or matrix will be skewed when applying world scale or oriented matrix
        local ctxMode = mode
        if band(operation, OPERATION.SCALE) ~= 0 then ctxMode = ImGuizmo.MODE.LOCAL end
        ComputeContext(view, projection, matrix, ctxMode)
        gContext.mHoveredHandleType = MT_NONE

        -- set delta to identity
        if deltaMatrix then
            matrix_t.SetToIdentity(deltaMatrix)
        end

        -- behind camera
        local camSpacePosition = makeVect(0, 0)
        camSpacePosition:TransformPoint(makeVect(0, 0, 0), gContext.mMVP)
        if not gContext.mIsOrthographic and camSpacePosition.z < 0.001 and not gContext.mbUsing then
            gContext.mDrawList:PopClipRect() -- [Port] upstream returns without popping; keep the clip stack balanced
            return false
        end

        -- --
        local type = MT_NONE
        local manipulated = false
        if gContext.mbEnable then
            if not gContext.mbUsingBounds then
                manipulated, type = HandleTranslation(matrix, deltaMatrix, operation, type, snap)
                if not manipulated then manipulated, type = HandleScale(matrix, deltaMatrix, operation, type, snap) end
                if not manipulated then manipulated, type = HandleRotation(matrix, deltaMatrix, operation, type, snap) end
            end
        end

        if localBounds and not gContext.mbUsing then
            manipulated = HandleAndDrawLocalBounds(localBounds, matrix, boundsSnap, operation) or manipulated
        end

        gContext.mOperation = operation
        if not gContext.mbUsing and not gContext.mbUsingBounds then
            gContext.mHoveredHandleType = type
        else
            gContext.mHoveredHandleType = MT_NONE
        end
        if not gContext.mbUsingBounds then
            DrawRotationGizmo(operation, type)
            DrawTranslationGizmo(operation, type)
            DrawScaleGizmo(operation, type)
            DrawScaleUniveralGizmo(operation, type)
        end

        gContext.mDrawList:PopClipRect()
        return manipulated
    end

    function ImGuizmo.SetGizmoSizeClipSpace(value)
        gContext.mGizmoSizeClipSpace = value
    end

    -- [Port] internals exposed for tests
    ImGuizmo._context = gContext
    ImGuizmo._worldToPos = worldToPos

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
