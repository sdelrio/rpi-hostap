# docs-site Agent Notes

## Starlight Component Overrides

### Header Layout Rule

**Never render extra sibling elements inside the `<slot name="header" />` of `PageFrame.astro`.**

The parent `PageFrame.astro` wraps the header slot in a fixed-position `<header class="header">` element:

```html
<header class="header"><slot name="header" /></header>
```

This parent element has `position: fixed; height: var(--sl-nav-height)`. Any extra child elements inside the slot (even with `display: none`) can cause layout displacement - the header content shifts up and controls move down.

**The fix**: If you need additional DOM elements (like a mobile menu), create them dynamically via JavaScript and append to `document.body`, not as siblings in the Astro template.

```js
// CORRECT: Create via JS, append to body
const menu = document.createElement('div');
menu.id = 'mobile-menu';
document.body.appendChild(menu);

// WRONG: Render as sibling in template
<div class="header">...</div>
<div class="mobile-menu" id="mobile-menu">...</div>  // This breaks layout!
```

### CSS Layer Awareness

- Starlight uses `@layer starlight.core` for component styles
- Unlayered CSS always wins over layered CSS per the CSS Cascade Layers spec
- Keep custom component styles inside `@layer starlight.core` to avoid specificity surprises
- Never put grid/layout overrides outside the layer

### Component Override Pattern

```js
// astro.config.mjs
components: {
  Header: './src/components/Header.astro',
  Footer: './src/components/Footer.astro',
}
```

Virtual imports available in overrides:
- `virtual:starlight/user-config`
- `virtual:starlight/components/Search`
- `virtual:starlight/components/ThemeSelect`
- `virtual:starlight/components/LanguageSelect`
- etc.

Import `Icon` from `@astrojs/starlight/components`, NOT from `../components`.
