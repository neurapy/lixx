#version 300 es
precision mediump float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

void main() {
    vec4 original = texture(tex, v_texcoord);
    // Keep the desktop readable while briefly tinting the whole screen red.
    fragColor = vec4(mix(original.rgb, vec3(1.0, 0.08, 0.04), 0.24), original.a);
}
