/*

OOGalaxyRenderer

An object which renders experimental 3D-ified Oolite galaxy data using WebGL.

Interface:
	Constructor:
		new OOGalaxyRenderer(galaxyURL, canvas)
		Create an OOGalaxyRenderer object.
		galaxyURL is the URL of a JSON file describing the galaxy.
		canvas is a web canvas element to use for rendering.
		
	Properties:
		route (array, default empty)
		An array of system indices defining a route to be travelled.
		
		showGrid (boolean, default true)
		If true, the possible jumps (less than seven LY apart) are rendered.
		
		showRoute (boolean, default false)
		If true, the route (see above) is rendered.
		
		viewDistance (number, default 150)
		The distance of the camera from the origin. This can be used to zoom
		(really dolly) the camera.
	
		
		onRouteChanged (function (old, new))
		A callback invoked when the route property is changed.
		
		onShowGridChanged(function())
		A callback invoked when the showGrid property is changed.
		
		onShowRouteChanged(function())
		A callback invoked when the showRoute property is changed.
		
		onViewDistanceChanged(function(old, new))
		A callback invoked when the viewDistance property is changed.
	
	
	Copyright © 2011 Jens Ayton
	
	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the “Software”), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:
	
	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.
	
	THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
*/


function OOGalaxyRenderer(galaxyURL, canvas)
{
"use strict";

var self = this;

// Private variables
var canvas;
var gl;
var solidColorShader, particleShader;
var starVBO, colorVBO, gridVBO, starParticleVBO, routeVBO;
var mvMatrix, rotMatrix, pMatrix;
var starCount, gridCount;
var starTexture;
var particleBaseSize;
var projectionDirty = true;
var console;


// MARK: Public properties
(function (){
var _showGrid = true;
Object.defineProperty(self, "showGrid",
{
	get: function() { return _showGrid; },
	set: function(value)
	{
		value = !!value;
		if (value != _showGrid)
		{
			_showGrid = value;
			
			if (self.onShowGridChanged)  self.onShowGridChanged();
			renderFrame();
		}
	}
});


var _showRoute = false;
Object.defineProperty(self, "showRoute",
{
	get: function() { return _showRoute; },
	set: function(value)
	{
		value = !!value;
		if (value != _showRoute)
		{
			_showRoute = value;
			
			if (self.onShowRouteChanged)  self.onShowRouteChanged();
			renderFrame();
		}
	}
});


var _route = [];

Object.defineProperty(self, "route",
{
	get: function() { return _route; },
	set: function(value)
	{
		if (!value)  value = [];
		
		if (value != _route)
		{
			var typeOK = true;
			if (!(value instanceof Array))  typeOK = false;
			else
			{
				value.forEach(function(x)
				{
					if (typeof(x) != "number")  typeOK = false;
				});
			}
			
			if (!typeOK)
			{
				throw new TypeError("route must be an array of star indices.");
			}
			
			var oldRoute = _route;
			_route = value;
			
			if (routeVBO)
			{
				gl.deleteBuffer(routeVBO);
				routeVBO = null;
			}
			
			if (self.onRouteChanged)  self.onRouteChanged(oldRoute, _route);
			
			renderFrame();
		}
	}
});


var _viewDistance = 150;
Object.defineProperty(self, "viewDistance",
{
	get: function () { return _viewDistance; },
	set: function(value)
	{
		value = +value;
		if (value > 0 && value != _viewDistance)
		{
			var oldViewDistance = _viewDistance;
			_viewDistance = value;
			projectionDirty = true;
			
			if (self.onViewDistanceChanged)  self.onViewDistanceChanged(oldViewDistance, _viewDistance);
			renderFrame();
		}
	}
});

})();


// MARK: Actual initializer
(function init()
{
	// Try to start a WebGL context.
	gl = canvas.getContext("experimental-webgl", { antialias: true });
	gl.viewportWidth = canvas.width;
	gl.viewportHeight = canvas.height;
	
	if (!gl)
	{
		throw new Error("WebGL not supported.");
	}
	
	if ("console" in window)  console = window.console;
	else console =  { log: function () {}, error: function () {} };
	
	gl.checkError = function checkError(context)
	{
		var err;
		while (err = this.getError())
		{
			console.log("GL error (" + context + "): " + err);
		}
	}
	
	// For some reason, the GL context raises errors outside of our code. We want to ignore those.
	gl.squashError = function squashError()
	{
		while (gl.getError()) ;
	}
	
	canvas.onmousedown = handleMouseDown;
	canvas.onmouseup = handleMouseUp;
	
	// Asynchronously load texture and galaxy data.
	loadStarTexture();
	loadGalaxyData();
	
	// Load our shaders while we wait.
	loadShaders();
	
	// Set up constant OpenGL state.
	gl.clearColor(0, 0, 0, 1);
	gl.enable(gl.BLEND);
	
	mvMatrix = new J3DIMatrix4();
	pMatrix = new J3DIMatrix4();
	rotMatrix = new J3DIMatrix4();
	rotMatrix.rotate(180, 0, 1, 0);
	rotMatrix.rotate(180, 0, 0, 1);
	
	// Start out empty.
	gl.clear(gl.COLOR_BUFFER_BIT);
	gl.flush();
})();


// MARK: Rendering
function renderFrame()
{
	gl.squashError();
	
	gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
	
	if (starVBO)
	{
		mvMatrix.makeIdentity();
		mvMatrix.multiply(rotMatrix);
		
		if (projectionDirty)
		{
			pMatrix.makeIdentity();
			pMatrix.perspective(30, canvas.width/canvas.height, 1, 1000);
			pMatrix.lookat(0, 0, self.viewDistance, 0, 0, 0, 0, 1, 0);
			particleBaseSize = canvas.height * 4 / self.viewDistance;
			projectionDirty = false;
		}
		
		gl.blendFunc(gl.SRC_ALPHA, gl.ONE);
		
		var showGrid = self.showGrid;
		var routeLength = self.route.length;
		var showRoute = routeLength && self.showRoute;
		
		if (showGrid || showRoute)
		{
			gl.useProgram(solidColorShader);
			mvMatrix.setUniform(gl, solidColorShader.uMVMatrix, false);
			pMatrix.setUniform(gl, solidColorShader.uPMatrix, false);
			
			gl.bindBuffer(gl.ARRAY_BUFFER, starVBO);
			gl.enableVertexAttribArray(solidColorShader.aPosition);
			gl.vertexAttribPointer(solidColorShader.aPosition, 3, gl.FLOAT, false, 0, 0);
		}
		
		if (showGrid)
		{
			gl.uniform4f(solidColorShader.uColor, 0.12, 0.18, 0.25, 1.0);
			gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, gridVBO);
			gl.drawElements(gl.LINES, gridCount * 2, gl.UNSIGNED_BYTE, 0);
		}
		
		if (showRoute)
		{
			if (!routeVBO)  buildRouteVBO();
			
			gl.uniform4f(solidColorShader.uColor, 0.8, 0.8, 0.2, 1.0);
			gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, routeVBO);
			gl.drawElements(gl.LINES, routeLength * 2, gl.UNSIGNED_BYTE, 0);
		}
		
		gl.useProgram(particleShader);
		mvMatrix.setUniform(gl, particleShader.uMVMatrix, false);
		pMatrix.setUniform(gl, particleShader.uPMatrix, false);
		gl.activeTexture(gl.TEXTURE0);
		gl.bindTexture(gl.TEXTURE_2D, starTexture);
		gl.uniform1i(particleShader.uTexture, 0);
		gl.uniform1f(particleShader.uParticleBaseSize, particleBaseSize);
		
		gl.bindBuffer(gl.ARRAY_BUFFER, starVBO);
		gl.enableVertexAttribArray(particleShader.aPosition);
		gl.vertexAttribPointer(particleShader.aPosition, 3, gl.FLOAT, false, 0, 0);
		
		gl.bindBuffer(gl.ARRAY_BUFFER, colorVBO);
		gl.enableVertexAttribArray(particleShader.aColor);
		gl.vertexAttribPointer(particleShader.aColor, 3, gl.FLOAT, false, 0, 0);
		
		gl.drawArrays(gl.POINTS, 0, starCount);
	}
	
	gl.flush();
	gl.checkError("after rendering");
}


// MARK: Data set-up
function loadedGalaxyData(data)
{
	gl.squashError();
	
	data = JSON.parse(data);
	var positions = data.positions;
	var colors = data.colors;
	var neighbours = data.neighbours;
	
	if (!positions || !colors || !neighbours || positions.length != colors.length)
	{
		alert("Galaxy data is invalid.");
		return;
	}
	
	starCount = positions.length / 3;
	gridCount = neighbours.length / 2;
//	console.log("Loaded galaxy data with " + starCount + " stars and " + gridCount + " routes.");
	
	starVBO = gl.createBuffer();
	gl.bindBuffer(gl.ARRAY_BUFFER, starVBO);
	gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(positions), gl.STATIC_DRAW);
	
	colorVBO = gl.createBuffer();
	gl.bindBuffer(gl.ARRAY_BUFFER, colorVBO);
	gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(colors), gl.STATIC_DRAW);
	
	gridVBO = gl.createBuffer();
	gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, gridVBO);
	gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, new Uint8Array(neighbours), gl.STATIC_DRAW);
	
	gl.checkError("after loading galaxy data");
	
	renderFrame();
}


function buildRouteVBO()
{
	if (routeVBO)  gl.deleteBuffer(routeVBO);
	var route = self.route;
	var routeLength = route.length;
	if (routeLength)
	{
		// Pack array of the form [1, 2, 2, 3, 3, … n - 1, n - 1, n].
		var routeIndices = new Uint8Array(routeLength * 2);
		routeIndices[0] = route[0];
		for (var i = 1; i < routeLength - 1; i++)
		{
			routeIndices[i * 2 - 1] = route[i];
			routeIndices[i * 2] = route[i];
		}
		routeIndices[routeLength * 2 - 3] = route[routeLength - 1];
		
		routeVBO = gl.createBuffer();
		gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, routeVBO);
		gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, routeIndices, gl.STATIC_DRAW);
	}
	else
	{
		routeVBO = null;
	}
}


// MARK: Resource loading
function loadStarTexture()
{
	starTexture = gl.createTexture();
	var starImage = new Image();
	starImage.onload = function ()
	{
		gl.bindTexture(gl.TEXTURE_2D, starTexture);
		gl.texImage2D(gl.TEXTURE_2D, 0, gl.LUMINANCE, gl.LUMINANCE, gl.UNSIGNED_BYTE, starImage);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_NEAREST);
		gl.generateMipmap(gl.TEXTURE_2D);
		
		if (starVBO)  renderFrame();
	};
	starImage.src = "oolite-star.png";
}


function loadGalaxyData()
{
	var galaxyReq = new XMLHttpRequest();
	galaxyReq.onreadystatechange = function ()
	{
		if (galaxyReq.readyState == 4)
		{
			if (galaxyReq.status == 200)
			{
				// Loaded OK.
				loadedGalaxyData(galaxyReq.responseText);
			}
			else
			{
				alert("The galaxy data could not be loaded from \"" + galaxyURL + "\".");
			}
		}
	};
	galaxyReq.open("GET", galaxyURL);
	galaxyReq.send();
}


function loadShaders()
{
	var shaders = shaderSource();
	var solidColorVertexShader = loadOneShader(shaders, "solidColorVertexShader", gl.VERTEX_SHADER);
	var solidColorFragmentShader = loadOneShader(shaders, "solidColorFragmentShader", gl.FRAGMENT_SHADER);
	var particleVertexShader = loadOneShader(shaders, "particleVertexShader", gl.VERTEX_SHADER);
	var particleFragmentShader = loadOneShader(shaders, "particleFragmentShader", gl.FRAGMENT_SHADER);
	
	solidColorShader = buildOneShaderProgram([solidColorVertexShader, solidColorFragmentShader], ["aPosition"], ["uMVMatrix", "uPMatrix", "uColor"]);
	particleShader = buildOneShaderProgram([particleVertexShader, particleFragmentShader], ["aPosition", "aSubCoordinates", "aColor"], ["uMVMatrix", "uPMatrix", "uParticleBaseSize"]);
	
	gl.checkError("after loading shaders");
}


function loadOneShader(shaders, name, type)
{
	var shaderText = shaders[name];
	if (!shaderText)
	{
		console.error("Could not find a shader named \"" + name + "\".");
		return null;
	}
	
	shaderText = "#ifdef GL_ES\nprecision mediump float;\n#endif\n" + shaderText;
	
	var shader = gl.createShader(type);
	gl.shaderSource(shader, shaderText);
	gl.compileShader(shader);
	
	if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS))
	{
		console.error("Failed to compile shader \"" + name + "\":\n" + gl.getShaderInfoLog(shader));
		return null;
	}
	
	return shader;
}


function buildOneShaderProgram(shaders, attributes, uniforms)
{
	gl.checkError("before building shader");
	
	var shaderProgram = gl.createProgram();
	gl.checkError("buildOneShaderProgram 1");
	
	for (var i = 0; i < shaders.length; i++)
	{
		gl.attachShader(shaderProgram, shaders[i]);
		gl.checkError("buildOneShaderProgram 2");
	}
	
	gl.linkProgram(shaderProgram);
	gl.checkError("buildOneShaderProgram 6");
	
	for (i = 0; i < attributes.length; i++)
	{
		var attribName = attributes[i];
		shaderProgram[attribName] = gl.getAttribLocation(shaderProgram, attribName);
		gl.checkError("buildOneShaderProgram 3 (" + attribName + ")");
		shaderProgram[attribName + "Loc"] = i;
	}
	
	for (i = 0; i < uniforms.length; i++)
	{
		var uniformName = uniforms[i];
		shaderProgram[uniformName] = gl.getUniformLocation(shaderProgram, uniformName);
		gl.checkError("buildOneShaderProgram 5 (" + uniformName + ")");
	}
	
	if (!gl.getProgramParameter(shaderProgram, gl.LINK_STATUS))
	{
		console.error("Failed to link shader:\n" + gl.getProgramInfoLog(shader));
		return null;
	}
	
	gl.checkError("after linking shader");
	
	return shaderProgram;
}


// MARK: Virtual trackball rotation
var dragPoint;

function handleMouseDown(event)
{
	if ((event.which || event.button) != 1)  return true;
	
	dragPoint = virtualTrackballLocation(event);
	canvas.onmousemove = handleMouseDrag;
	return false;
}


function handleMouseDrag(event)
{
	var newDragPoint = virtualTrackballLocation(event);
	var delta = vectorSubtract(newDragPoint, dragPoint);
	
	var deltaMag = vectorMagnitude(delta);
	if (0.001 < deltaMag)
	{
		// Rotate about the axis that is perpendicular to the great circle connecting the mouse points.
		var axis = vectorCrossProduct(dragPoint, newDragPoint);
		
		/*
			Silliness because rotate() is backwards. I could probably fix this
			by opening a maths book and inserting a bunch of transposes and
			inverts, but it doesn’t seem worth it. Will need to write my own
			JS matrix library at some point anyway.
			-- Ahruman 2011-04-14
		*/
		var rot = new J3DIMatrix4;
		rot.rotate(deltaMag * 180 / Math.PI, vectorNormal(axis));
		rot.multiply(rotMatrix);
		rotMatrix = rot;
		
		renderFrame();
		dragPoint = newDragPoint;
	}
}


function handleMouseUp(event)
{
	canvas.onmousemove = null;
	document.body.style.cursor = "default";
}


// Given an event, return a trackball direction vector (as an array of three numbers).
function virtualTrackballLocation(event)
{
	var width = canvas.width, height = canvas.height;
	var x = (event.clientX - canvas.offsetLeft);
	var y = (event.clientY - canvas.offsetTop);
	
	x = (2 * x - width) / width;
	y = -(2 * y - height) / height;
	
	var d = Math.min(1, vectorSquareMagnitude([x, y]));
	var z = Math.sqrt(1.0001 - d);
	
	return vectorNormal([x, y, z]);
}


// MARK: Overly generic vector routines.
function vectorAdd(u, v)
{
	return u.map(function(x, idx) { return x + v[idx]; });
}


function vectorSubtract(u, v)
{
	return u.map(function(x, idx) { return x - v[idx]; });
}


function vectorSquareMagnitude(v)
{
	return v.reduce(function(a, x) { return a + x * x; }, 0);
}


function vectorMagnitude(v)
{
	return Math.sqrt(vectorSquareMagnitude(v));
}


function vectorScale(v, s)
{
	return v.map(function(n) { return n * s; });
}


function vectorNormal(v)
{
	return vectorScale(v, 1 / vectorMagnitude(v));
}


function vectorDotProduct(u, v)
{
	return u.reduce(function(a, x, idx) { return a + x * v[idx]; }, 0);
}


// Less generic, since it’s only (unambiguously) defined in three dimensions.
function vectorCrossProduct(u, v)
{
	return [
		u[1] * v[2] - v[1] * u[2],
		u[2] * v[0] - v[2] * u[0],
		u[0] * v[1] - v[0] * u[1]
	];
}


function shaderSource() { return {

// Vertex and fragment shader for solid-colour lines.
solidColorVertexShader:
"attribute vec3 aPosition;" +

"uniform mat4 uMVMatrix;" +
"uniform mat4 uPMatrix;" +

"void main(void)" +
"{" +
"	gl_Position = uPMatrix * uMVMatrix * vec4(aPosition, 1.0);" +
"}",


solidColorFragmentShader:
"uniform vec4 uColor;" +

"void main(void)" +
"{" +
"	gl_FragColor = uColor;" +
"}",


// Vertex and fragment shader for textured particles.
particleVertexShader:
"attribute vec3 aPosition;" +
"attribute vec3 aColor;" +

"uniform mat4 uMVMatrix;" +
"uniform mat4 uPMatrix;" +
"uniform float uParticleBaseSize;" +

"varying vec4 vColor;" +

"void main(void)" +
"{" +
"	vColor = vec4(aColor * 0.8, 1.0);" +
"	gl_PointSize = uParticleBaseSize;" +	// FIXME: perspective.
"	gl_Position = uPMatrix * uMVMatrix * vec4(aPosition, 1.0);" +
"}",

particleFragmentShader:
"varying vec4 vColor;" +
"uniform sampler2D uTexture;" +

"void main(void)" +
"{" +
"	gl_FragColor = vColor * texture2D(uTexture, gl_PointCoord);" +
"}"

};}

};
