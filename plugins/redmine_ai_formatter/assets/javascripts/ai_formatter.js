(function() {
  'use strict';

  // On DOMContentLoaded, all scripts have loaded and inline draw() calls have run.
  // We find every jstBlock toolbar via the DOM and add AI features directly.
  document.addEventListener('DOMContentLoaded', function() {
    if (!window.aiFormatterSettings) return;

    // Enhance all existing toolbars on the page
    document.querySelectorAll('.jstBlock').forEach(function(block) {
      addAiFeaturesToBlock(block);
    });

    // Patch draw() for any toolbars created dynamically after page load
    if (typeof jsToolBar !== 'undefined') {
      var originalDraw = jsToolBar.prototype.draw;
      jsToolBar.prototype.draw = function(mode) {
        originalDraw.call(this, mode);
        if (this.textarea) this.textarea._jsToolBarInstance = this;
        addAiFeaturesToBlock(this.toolbarBlock);
      };
    }
  });

  // Add AI features by walking the DOM structure that jsToolBar creates:
  //   .jstBlock > .jstTabs > ul (contains Edit/Preview tabs)
  //   .jstBlock > .jstEditor > textarea + .wiki-preview
  //   .jstBlock > .jstTabs .jstElements (toolbar buttons)
  function addAiFeaturesToBlock(block) {
    if (!block || block._aiFormatterAdded) return;

    var textarea = block.querySelector('.jstEditor textarea');
    var tabsBlock = block.querySelector('.jstTabs');
    var toolbarEl = block.querySelector('.jstElements');
    var editor = block.querySelector('.jstEditor');
    var preview = block.querySelector('.wiki-preview');

    if (!textarea || !tabsBlock || !toolbarEl || !editor) return;

    block._aiFormatterAdded = true;

    // Build a lightweight proxy object with the properties our functions need
    var ctx = {
      textarea: textarea,
      tabsBlock: tabsBlock,
      toolbar: toolbarEl,
      editor: editor,
      preview: preview,
      toolbarBlock: block,
      _aiPromptPanel: null,
      _aiPromptTextarea: null
    };

    addAiPromptTab(ctx);
    addAiToolbarButton(ctx);
  }

  // --- AI Prompt Tab ---
  function addAiPromptTab(ctx) {
    var settings = window.aiFormatterSettings;

    // Create the AI Prompt tab (alongside Edit and Preview)
    var aiTab = document.createElement('li');
    var aiLink = document.createElement('a');
    aiLink.setAttribute('href', '#');
    aiLink.innerText = 'AI Prompt';
    aiLink.className = 'tab-ai_prompt';
    aiTab.appendChild(aiLink);

    // Insert tab after Preview tab (second li in the tabs ul)
    var tabsList = ctx.tabsBlock.querySelector('ul');
    var tabItems = tabsList.querySelectorAll('li');
    // Preview is typically the 2nd tab item; insert after it
    if (tabItems.length >= 2) {
      var previewLi = tabItems[1];
      if (previewLi.nextSibling) {
        tabsList.insertBefore(aiTab, previewLi.nextSibling);
      } else {
        tabsList.appendChild(aiTab);
      }
    } else {
      tabsList.appendChild(aiTab);
    }

    // Create the AI Prompt panel (hidden by default)
    var panel = document.createElement('div');
    panel.className = 'ai-prompt-panel';

    var promptTextarea = document.createElement('textarea');
    promptTextarea.value = settings.defaultPrompt || '';
    promptTextarea.setAttribute('rows', '4');
    panel.appendChild(promptTextarea);

    var actions = document.createElement('div');
    actions.className = 'ai-prompt-actions';

    var formatBtn = document.createElement('button');
    formatBtn.setAttribute('type', 'button');
    formatBtn.innerText = 'Format with AI';
    formatBtn.addEventListener('click', function() {
      runAiFormat(ctx, promptTextarea.value);
    });
    actions.appendChild(formatBtn);

    var resetBtn = document.createElement('button');
    resetBtn.setAttribute('type', 'button');
    resetBtn.className = 'ai-prompt-reset';
    resetBtn.innerText = 'Reset to default';
    resetBtn.addEventListener('click', function() {
      promptTextarea.value = settings.defaultPrompt || '';
    });
    actions.appendChild(resetBtn);

    panel.appendChild(actions);

    // Insert panel before the editor area
    ctx.toolbarBlock.insertBefore(panel, ctx.editor);

    // Store references
    ctx._aiPromptPanel = panel;
    ctx._aiPromptTextarea = promptTextarea;

    // Tab click handler — toggle AI Prompt panel
    aiLink.addEventListener('click', function(e) {
      e.preventDefault();
      var isVisible = panel.classList.contains('visible');

      if (isVisible) {
        // Hide prompt panel, restore edit view
        panel.classList.remove('visible');
        aiLink.classList.remove('selected');
        ctx.toolbar.classList.remove('hidden');
        ctx.textarea.classList.remove('hidden');
        ctx.tabsBlock.querySelector('.tab-edit').classList.add('selected');
      } else {
        // Show only the prompt panel, hide editor textarea and toolbar (like Preview)
        panel.classList.add('visible');
        aiLink.classList.add('selected');
        ctx.toolbar.classList.add('hidden');
        ctx.textarea.classList.add('hidden');
        if (ctx.preview) ctx.preview.classList.add('hidden');
        ctx.tabsBlock.querySelector('.tab-edit').classList.remove('selected');
        ctx.tabsBlock.querySelector('.tab-preview').classList.remove('selected');
      }
    });

    // Hide AI panel when Edit or Preview tab is clicked
    var editLink = ctx.tabsBlock.querySelector('.tab-edit');
    var previewLink = ctx.tabsBlock.querySelector('.tab-preview');

    if (editLink) {
      editLink.addEventListener('click', function() {
        panel.classList.remove('visible');
        aiLink.classList.remove('selected');
      });
    }
    if (previewLink) {
      previewLink.addEventListener('click', function() {
        panel.classList.remove('visible');
        aiLink.classList.remove('selected');
      });
    }
  }

  // --- AI Toolbar Button ---
  function addAiToolbarButton(ctx) {
    var btn = document.createElement('button');
    btn.setAttribute('type', 'button');
    btn.className = 'jstb_ai_format';
    btn.title = 'Format with AI';
    btn.tabIndex = 200;

    var span = document.createElement('span');
    span.appendChild(document.createTextNode('Format with AI'));
    btn.appendChild(span);

    btn.addEventListener('click', function() {
      var customPrompt = null;
      if (ctx._aiPromptTextarea) {
        customPrompt = ctx._aiPromptTextarea.value;
      }
      runAiFormat(ctx, customPrompt);
    });

    // Add a separator space then the button
    var spacer = document.createElement('span');
    spacer.className = 'jstSpacer';
    spacer.innerHTML = '&nbsp;';

    ctx.toolbar.appendChild(spacer);
    ctx.toolbar.appendChild(btn);
  }

  // --- AJAX call to AI API ---
  function runAiFormat(ctx, customPrompt) {
    var settings = window.aiFormatterSettings;
    var text = ctx.textarea.value;

    if (!settings.configured) {
      alert('AI Formatter is not configured. Please set the AI API Key in Administration > Settings > AI.');
      return;
    }

    if (!text || text.trim() === '') {
      alert('No text to format.');
      return;
    }

    // Show inline loading indicator at top of block
    ctx.editor.classList.add('ai-loading');
    ctx.textarea.disabled = true;
    var loadingBar = document.createElement('div');
    loadingBar.className = 'ai-loading-bar';
    loadingBar.innerHTML = '<div class="ai-spinner"></div><span>AI is generating...</span>';
    ctx.toolbarBlock.insertBefore(loadingBar, ctx.toolbarBlock.firstChild);

    // Disable AI buttons
    var aiButtons = ctx.toolbarBlock.querySelectorAll('.jstb_ai_format, .ai-prompt-actions button');
    aiButtons.forEach(function(b) { b.disabled = true; });

    var body = new FormData();
    body.append('text', text);
    if (customPrompt && customPrompt.trim() !== '') {
      body.append('custom_prompt', customPrompt);
    }

    fetch(settings.formatUrl, {
      method: 'POST',
      headers: {
        'X-CSRF-Token': settings.csrfToken
      },
      body: body
    })
    .then(function(response) {
      return response.json().then(function(data) {
        return { ok: response.ok, data: data };
      });
    })
    .then(function(result) {
      ctx.editor.classList.remove('ai-loading');
      ctx.textarea.disabled = false;
      var bar = ctx.toolbarBlock.querySelector('.ai-loading-bar');
      if (bar) bar.remove();
      var aiButtons = ctx.toolbarBlock.querySelectorAll('.jstb_ai_format, .ai-prompt-actions button');
      aiButtons.forEach(function(b) { b.disabled = false; });

      if (!result.ok) {
        alert('AI formatting error: ' + (result.data.error || 'Unknown error'));
        return;
      }

      if (result.data.formatted_text) {
        ctx.textarea.value = result.data.formatted_text;
        ctx.textarea.focus();
      }
    })
    .catch(function(err) {
      ctx.editor.classList.remove('ai-loading');
      ctx.textarea.disabled = false;
      var bar = ctx.toolbarBlock.querySelector('.ai-loading-bar');
      if (bar) bar.remove();
      var aiButtons = ctx.toolbarBlock.querySelectorAll('.jstb_ai_format, .ai-prompt-actions button');
      aiButtons.forEach(function(b) { b.disabled = false; });
      alert('AI formatting error: ' + err.message);
    });
  }
})();
