/*
	OO3D
	A collection of types for linear algebra for 3D graphics work.
	
	OO3D.Vector3D
	A vector in 3-space.
	This is designed to behave like the Vector3D type in Oolite’s JavaScript interface.
	For documentation, see http://wiki.alioth.net/index.php/Oolite_JavaScript_Reference:_Vector3D
	Some methods are unimplemented, namely:
		fromCoordinateSystem() and toCoordinateSystem()
		rotateBy() and rotationTo()
		random(), randomDirection() and randomDirectionAndLength()
	
	OO3D.Matrix4x4
	A 4x4 transformation matrix. (No equivalent in Oolite at the moment.)
	
	OO3D.Quaternion
	Unimplemented.
*/


OO3D = {};


// MARK: Vector3D

(function () {
"use strict";

function Vector3D(val)
{
	if (this instanceof Vector3D)  var self = this;
	else  var self = new Vector3D;
	
	if (arguments.length == 0)
	{
		self.x = 0;
		self.y = 0;
		self.z = 0;
	}
	else if (arguments.length == 3)
	{
		self.x = arguments[0];
		self.y = arguments[1];
		self.z = arguments[2];
	}
	else if (arguments.length == 1)
	{
		if ("x" in val)
		{
			self.x = val.x;
			self.y = val.y;
			self.z = val.z;
		}
		else if ("length" in val && val.length == 3)
		{
			self.x = val[0];
			self.y = val[1];
			self.z = val[2];
		}
	}
	else
	{
		throw new TypeError("Invalid initializer for OO3D.Vector3D.");
	}
	
	Object.seal(self);
	return self;
}

OO3D.Vector3D = Vector3D;


function cleanVector(v)
{
	if (v instanceof Vector3D)  return v;
	else if (v instanceof Array)  return new Vector3D(v);
	else if ("position" in v)  return cleanVector(v.position);
	else
	{
		throw new TypeError("Not a vector.");
	}
}


Vector3D.prototype =
{
add: function (other)
{
	other = cleanVector(other);
	return new OO3D.Vector(this.x + other.x, this.y + other.y, this.z + other.z);
},

cross: function (other)
{
	return new Vector3D(
		this.y * other.z - other.y * this.z,
		this.z * other.x - other.z * this.x,
		this.x * other.y - other.x * this.y
	);
},

direction: function ()
{
	return this.multiply(1 / this.magnitude());
},

distanceTo: function (other)
{
	return this.subtract(other).magnitude();
},

dot: function (other)
{
	other = cleanVector(other);
	return this.x * other.x + this.y * other.y + this.z * other.z;
},

flip: function ()
{
	return new Vector3D(-this.x, -this.y, -this.z);
},

// fromCoordinateSystem: requires a system.

magnitude: function ()
{
	return Math.sqrt(this.squaredMagnitude());
},

multiply: function (f)
{
	return new Vector3D(this.x * f, this.y * f, this.z * f);
},

// rotateBy: no quaternions.
// rotationTo: no quaternions.

squaredDistanceTo: function (other)
{
	return this.subtract(other).squaredMagnitude();
},

squaredMagnitude: function ()
{
	return this.x * this.x + this.y * this.y + this.z * this.z;
},

subtract: function (other)
{
	other = cleanVector(other);
	return new Vector3D(this.x - other.x, this.y - other.y, this.z - other.z);
},

toArray: function ()
{
	return [this.x, this.y, this.z];
},

// toCoordinateSystem: requires a system.

toSource: function ()
{
	return "new OOJS.Vector3D(" + this.x + ", " + this.y + ", " + this.z + ")";
},

toString: function ()
{
	return "(" + this.x + ", " + this.y + ", " + this.z + ")";
},

tripleProduct: function (v, w)
{
	return this.dot(v.cross(w));
}

};


Vector3D.interpolate = function (u, v, where)
{
	return u.add(v.subtract(u).multiply(where));
}

// random, randomDirection, randomDirectionAndLength: not implemented.


// MARK: Matrix4x4

function Matrix4x4(val)
{
	if (this instanceof Matrix4x4)  var self = this;
	else  var self = new Matrix4x4;
	
	if (val === undefined)
	{
		self.$m = new Array(16);
		self.setIdentity();
	}
	else if (val instanceof Matrix4x4)
	{
		self.$m = Matrix4x4.m.slice(0, 16);
	}
	else if (typeof val == "object" && "length" in val && val.length == 16)
	{
		self.$m = Array.prototype.slice.call(val, 0, 16);
	}
	else if (arguments.length == 16)
	{
		self.$m = Array.prototype.slice.call(arguments, 0, 16);
	}
	else if (val instanceof Vector3D && arguments.length == 3 || arguments.length == 4)
	{
		// Init with basis vectors and optional offset.
		var i = val;
		var j = arguments[1];
		var k = arguments[2];
		var p = (arguments.length == 4) ? arguments[3] : new Vector3D;
		
		self.$m = [
			i.x, i.y, i.z, 0,
			j.x, j.y, j.z, 0,
			k.x, k.y, k.z, 0,
			p.x, p.y, p.z, 1
		];
	}
	else
	{
		throw new TypeError("Invalid initializer for OO3D.Matrix4x4.");
	}
	
	Object.seal(self);
	return self;
}

OO3D.Matrix4x4 = Matrix4x4;


Matrix4x4.prototype = {

multiply: function (other)
{
	var a = this.$m;
	var b = other.$m;
	var r = new Array(16);
	
	// You are not expected to understand this.
	var i;
	for (i = 0; i < 4; i++)
	{
		r[i   ] = a[i] * b[ 0] + a[i+4] * b[ 1] + a[i+8] * b[ 2] + a[i+12] * b[ 3];
		r[i+ 4] = a[i] * b[ 4] + a[i+4] * b[ 5] + a[i+8] * b[ 6] + a[i+12] * b[ 7];
		r[i+ 8] = a[i] * b[ 8] + a[i+4] * b[ 9] + a[i+8] * b[10] + a[i+12] * b[11];
		r[i+12] = a[i] * b[12] + a[i+4] * b[13] + a[i+8] * b[14] + a[i+12] * b[15];
	}
	
	this.$m = r;
},

rotate: function (axis, angle)
{
	return this.multiply(Matrix4x4.matrixForRotation(axis, angle));
},

rotateX: function (angle)
{
	return this.multiply(Matrix4x4.matrixForRotationX(angle));
},

rotateY: function (angle)
{
	return this.multiply(Matrix4x4.matrixForRotationY(angle));
},

rotateZ: function (angle)
{
	return this.multiply(Matrix4x4.matrixForRotationZ(angle));
},

scale: function (factor)
{
	return this.multiply(Matrix4x4.matrixForScale(factor));
},

setIdentity: function ()
{
	this.$m[ 0] = 1;	this.$m[ 1] = 0;	this.$m[ 2] = 0;	this.$m[ 3] = 0;
	this.$m[ 4] = 0;	this.$m[ 5] = 1;	this.$m[ 6] = 0;	this.$m[ 7] = 0;
	this.$m[ 8] = 0;	this.$m[ 9] = 0;	this.$m[10] = 1;	this.$m[11] = 0;
	this.$m[12] = 0;	this.$m[13] = 0;	this.$m[14] = 0;	this.$m[15] = 1;
},

toArray: function ()
{
	return this.$m.slice(0, 16);
},

toFloat32Array: function ()
{
	return new Float32Array(this.$m);
},

toString: function ()
{
	return "[" + this.$m.join(", ") + "]";
},

translate: function (offset)
{
	this.multiply(Matrix4x4.matrixForTranslation(offset));
},

transpose: function ()
{
	var i, j;
	for (i = 0; i < 4; i++)
	{
		for (j = 0; j < 4; j++)
		{
			var temp = this.$m[i * 4 + j];
			this.$m[i * 4 + j] = this.$m[i + 4 * j];
			this.$m[i + 4 * j] = temp;
		}
	}
},


// MARK: Projection matrix utilities

// Equivlent to glFrustum(), see http://www.opengl.org/sdk/docs/man/xhtml/glFrustum.xml
frustum: function (left, right, bottom, top, nearVal, farVal)
{
	var A = (right + left)/(right - left);
	var B = (top + bottom)/(top - bottom);
	var C = -((farVal + nearVal)/(farVal - nearVal));
	var D = -((2 * farVal * nearVal) / (farVal - nearVal));
	
	var M = new Matrix4x4(
		((2 * nearVal)/(right - left)),   0,                              0,  0,
		0,                              ((2 * nearVal) / (top - bottom)), 0,  0,
		A,                                B,                              C, -1,
		0,                                0,                              D,  0
	);
	this.multiply(M);
},

// Equivalent to gluLookAt(), see http://www.opengl.org/sdk/docs/man/xhtml/gluLookAt.xml
lookAt: function (eye, center, up)
{
	eye = cleanVector(eye);
	center = cleanVector(center);
	up = cleanVector(up);
	
	var F = center.subtract(eye);
	var f = F.direction();
	var upN = up.direction();
	var s = f.cross(upN);
	var u = s.cross(f);
	
	var M = new Matrix4x4(
		s.x, u.x, -f.x, 0,
		s.y, u.y, -f.y, 0,
		s.z, u.z, -f.z, 0,
		0,   0,    0,   1
	);
	this.multiply(M);
	this.translate(eye.flip());
},

// Equivalent to gluPerspective(), see http://www.opengl.org/sdk/docs/man/xhtml/gluPerspective.xml and http://www.opengl.org/resources/faq/technical/transformations.htm#tran0085
perspective: function (fovy, aspect, zNear, zFar)
{
	var top = Math.tan(fovy * Math.PI/360) * zNear;
	var right = aspect * top;
	
	this.frustum(-right, right, -top, top, zNear, zFar);
},


// MARK: Shader state helpers
setUniform: function (gl, location)
{
	gl.uniformMatrix4fv(location, false, this.toFloat32Array());
},

setUniformTransposed: function (gl, location)
{
	gl.uniformMatrix4fv(location, true, this.toFloat32Array());
}

};


// MARK: Matrix4x4 factories

Matrix4x4.matrixForRotation = function (axis, angle)
{
	axis = cleanVector(axis).direction();
	
	var x = axis.x, y = axis.y, z = axis.z;
	var s = Math.sin(angle), c = Math.cos(angle);
	var t = 1 - c;
	
	// Common subexpressions.
	var sx = s * x;
	var sy = s * y;
	var sz = s * z;
	var tx = t * x, ty = t * y;
	var txy = tx * y, tyz = ty * z;
	
	return new Matrix4x4(
		tx * x + c,	txy + sz,	tx * z - sy,	0,
		txy - sz,	ty * y + c,	tyz + sx,		0,
		txy + sy,	tyz - sx,	t * z * z + c,	0,
		0,			0,			0,				1
	);
}


// Equivalent to Matrix4x4.matrixForRotation([1, 0, 0], angle)
Matrix4x4.matrixForRotationX = function (angle)
{
	var s = Math.sin(angle), c = Math.cos(angle);
	
	return new Matrix4x4(
		1,  0,  0,  0,
		0,  c,  s,  0,
		0, -s,  c,  0,
		0,  0,  0,  1
	);
}


// Equivalent to Matrix4x4.matrixForRotation([0, 1, 0], angle)
Matrix4x4.matrixForRotationY = function (angle)
{
	var s = Math.sin(angle), c = Math.cos(angle);
	
	return new Matrix4x4(
		c,  0, -s,  0,
		0,  1,  0,  0,
		s,  0,  c,  0,
		0,  0,  0,  1
	);
}


// Equivalent to Matrix4x4.matrixForRotation([0, 0, 1], angle)
Matrix4x4.matrixForRotationZ = function (angle)
{
	var s = Math.sin(angle), c = Math.cos(angle);
	
	return new Matrix4x4(
	    c,  s,  0,  0,
	   -s,  c,  0,  0,
	    0,  0,  1,  0,
	    0,  0,  0,  1
	);
}


Matrix4x4.matrixForScale = function (factor)
{
	if (factor instanceof Vector3D)
	{
		return new Matrix4x4(
			factor.x, 0,        0,        0,
			0,        factor.y, 0,        0,
			0,        0,        factor.z, 0,
			0,        0,        0,        1
		);
	}
	else
	{
		return new Matrix4x4(
			factor, 0,      0,      0,
			0,      factor, 0,      0,
			0,      0,      factor, 0,
			0,      0,      0,      1
		);
	}
}


Matrix4x4.matrixForTranslation = function (offset)
{
	return new Matrix4x4(
		1,			0,			0,			0,
		0,			1,			0,			0,
		0,			0,			1,			0,
		offset.x,	offset.y,	offset.z,	1
	);
}

})();
