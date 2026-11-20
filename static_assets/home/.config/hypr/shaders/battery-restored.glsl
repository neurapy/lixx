#version 300 es
precision mediump float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

void main() {
    vec4 original = texture(tex, v_texcoord);
    // Match the warning tint, using blue to signal that power is restored.
    fragColor = vec4(mix(original.rgb, vec3(0.04, 0.35, 1.0), 0.24), original.a);
}
