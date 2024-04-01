#if defined(VERTEX)

#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#define COMPAT_TEXTURE texture
#else
#define COMPAT_VARYING varying 
#define COMPAT_ATTRIBUTE attribute 
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

uniform   mat4 MVPMatrix;
COMPAT_ATTRIBUTE vec2 VertexCoord;
COMPAT_ATTRIBUTE vec2 TexCoord;
COMPAT_ATTRIBUTE vec4 COLOR;
COMPAT_VARYING   vec2 v_tex;

COMPAT_VARYING vec4 COL0;
COMPAT_VARYING vec4 TEX0;
COMPAT_VARYING vec2 invDims;

uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;

void main(void)                                    
{                                                  
	gl_Position = MVPMatrix * vec4(VertexCoord.xy, 0.0, 1.0);
	v_tex       = TexCoord;                           
	COL0       = COLOR;        
	TEX0.xy = TexCoord.xy * 1.00001;
    invDims=1.0/TextureSize.xy;                       
}

#elif defined(FRAGMENT)
			
#if __VERSION__ >= 130
#define COMPAT_VARYING in
#define COMPAT_TEXTURE texture
out vec4 FragColor;
#else
#define COMPAT_VARYING varying
#define FragColor gl_FragColor
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif
			
COMPAT_VARYING   vec4      COL0;
COMPAT_VARYING   vec2      v_tex;
COMPAT_VARYING   vec4      TEX0;
COMPAT_VARYING   vec2      invDims;

uniform   sampler2D u_tex;
uniform   COMPAT_PRECISION vec2      resolution;
uniform   COMPAT_PRECISION vec2      TextureSize;
uniform   COMPAT_PRECISION vec2      OutputSize;
uniform   COMPAT_PRECISION int FrameDirection;
uniform   COMPAT_PRECISION int FrameCount;

uniform   COMPAT_PRECISION float      blur;

#define SCANTHICK 2.0
#define INTENSITY 0.15
#define BRIGHTBOOST 0.15
#define CGWG 0.3
#define BLUR 0.6
#define GAMMA 0.45
#define SATURATION 1.0
#define shadowmask 0.0
#define msk_size 1.0

vec3 mask(float p)
{
    p = floor(p/msk_size);

    vec3 Mask = vec3(1.0);
    float m=1.0-CGWG;

    if (shadowmask == 0.0)
    {
    float pos = fract (p*0.5);

    if (pos < 0.5) {Mask.r=1.0, Mask.g=m, Mask.b=1.0;}
    else {Mask.r=m, Mask.g=1.0, Mask.b=m;}
    }

    if (shadowmask == 1.0)
    {
    float pos = fract (p*0.3333);

    if (pos<0.333) {Mask.r=1.0, Mask.g=m, Mask.b=m;}
    else if (pos<0.666) {Mask.r=m, Mask.g=1.0, Mask.b=m;}
    else {Mask.r=m, Mask.g=m, Mask.b=1.0;}
    }
    
    return Mask;
}

//SIMPLE AND FAST SATURATION
vec3 saturation (vec3 textureColor)

{
    vec3 luminanceWeighting = vec3(0.3, 0.6, 0.1);
    float luminance = dot(textureColor.rgb, luminanceWeighting);
    vec3 greyScaleColor = vec3(luminance);

    vec3 res = vec3(mix(greyScaleColor, textureColor.rgb, SATURATION));
    return res;
}

float randomValue(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233) + 5.0)) * 43758.5453);
}

void main(void)                                    
{         
	float blurSize = blur;
	if (blurSize == 0.0) {
		blurSize = 3.0;
	}
	
	int numSamples = 13;
	
	// Initialize a color accumulator
	vec4 blurColor = COMPAT_TEXTURE(u_tex, v_tex) * float(numSamples);

	// Calculate the step size for sampling the scene texture
	vec2 stepSize = 1.0 / TextureSize;

	float pixels = 2.0;
	int total = numSamples;
	
	for (int i = 0; i < numSamples; i++) {
		vec2 offset = vec2(cos(float(i) * 3.14159 * 2.0 / float(numSamples)), sin(float(i) * 3.14159 * 2.0 / float(numSamples)));		
	    for (int b = 1; b < int(blurSize); b++) {	    
			blurColor += COMPAT_TEXTURE(u_tex, v_tex + offset * float(b) * stepSize * 1.5);	
			total++;
		}
	}

	// Normalize the accumulated color
	blurColor /= float(total);

	// Output the final blurred color
	// FragColor = blurColor;
	
	vec2 pos = TEX0.xy;
    vec2 p = pos * TextureSize; 
    vec2 i = floor(p)*1.0001 + 0.5;
    vec2 f = p - i;
    p = (i + 4.0*f*f*f)*invDims;
    p.x = mix(p.x, pos.x, BLUR);
  
   //animate strength

    vec3 texel = blurColor.rgb;
    vec3 pixelHigh = ((1.0 + BRIGHTBOOST) - (0.2 * texel)) * texel;
    vec3 pixelLow  = ((1.0 - INTENSITY) + (0.1 * texel)) * texel;
    float selectY = mod(TEX0.y * SCANTHICK * TextureSize.y, 2.0);
    float selectHigh = step(1.0, selectY);
    float selectLow = 1.0 - selectHigh;
    vec3 pixelColor = (selectLow * pixelLow) + (selectHigh * pixelHigh);
    pixelColor*=pixelColor;
    pixelColor*= mask(gl_FragCoord.x);

    pixelColor = pow(pixelColor,vec3(GAMMA));
    pixelColor= saturation(pixelColor);
	
    FragColor = vec4(pixelColor, 1.0);
	/*
	// Noise effect
    int anim = int(mod(float(FrameCount), 25.0)); 
  	  
	vec2 uv = gl_FragCoord.xy / resolution;
    float seed = float(anim);

    // Generate random noise
    float noise = randomValue(uv + seed);

    // Output the final color with noise
    vec4 pxNoised = vec4(vec3(noise), 1.0);
	
	vec3 finalColor = mix(pixelColor, vec3(noise), 0.1);

	FragColor = vec4(finalColor, 1.0);*/
}
#endif
