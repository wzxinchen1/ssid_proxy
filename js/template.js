/**
 * 简易模板引擎
 * 支持功能：
 * 1. 单向绑定（{{变量名}}）
 * 2. 事件绑定（事件名="函数名"）
 * 3. v-for 循环（v-for="item in items"）
 * 4. v-for-empty 支持（v-for-empty="无数据"）
 * 5. v-value 支持（v-value="xxx"，用于 select 标签选中匹配的 option）
 */

export class Template {
  constructor(templateString) {
    this.templateString = templateString;
    this.compiled = this.compile();
    // 检查是否有 v-for
    this.hasVFor = this.templateString.includes('v-for');
    this.vForElements = [];
    if (this.hasVFor) {
      this.vForElements = this._findVForElements(this.domTree);
    }
  }

  /**
   * 编译模板
   * @param {string} template - 模板字符串
   * @returns {object} 编译结果对象
   */
  compile() {
    // 解析模板为 DOM 树
    const templateElement = document.createElement("template");
    templateElement.innerHTML = this.templateString;
    this.domTree = templateElement.content.firstElementChild;

    return undefined;
  }

  /**
   * 渲染模板
   * @param {object} data - 数据对象
   * @returns {HTMLElement} 渲染后的 DOM 元素
   */
  render(data) {
    // 克隆 DOM 树
    const clonedTree = this.domTree.cloneNode(true);
    this.compile();
    // 处理 v-for 元素
    if (this.hasVFor) {
      this.vForElements = this._findVForElements(clonedTree);
      this._processVForElements(this.templateString, clonedTree, this.vForElements, data);
    }

    // 处理单向绑定和事件绑定
    this._processBindings(clonedTree, data);

    return clonedTree;
  }

  /**
   * 查找所有 v-for 元素
   * @param {HTMLElement} element - 根元素
   * @returns {Array} v-for 元素列表
   */
  _findVForElements(element) {
    const vForElements = [];

    // 递归查找 v-for 属性
    const walk = (node) => {
      if (node.hasAttribute('v-for')) {
        vForElements.push(node);
      }

      // 遍历子节点
      for (const child of node.children) {
        walk(child);
      }
    };

    walk(element);
    return vForElements;
  }

  /**
   * 处理 v-for 元素
   * @param {HTMLElement} root - 根元素
   * @param {Array} vForElements - v-for 元素列表
   * @param {object} data - 数据对象
   */
  _processVForElements(template, root, vForElements, data) {
    for (let i = 0; i < vForElements.length; i++) {
      const element = vForElements[i];
      const vForValue = element.getAttribute('v-for');
      const vForEmpty = element.getAttribute('v-for-empty');
      const [itemVar, listVar] = vForValue.split(' in ');
      let list = data[listVar.trim()] || [];
      if (!Array.isArray(list)) {
        console.error(`v-for 数据 ${listVar} 不是数组`);
        continue;
      }

      // 移除 v-for 和 v-for-empty 属性
      element.removeAttribute('v-for');
      if (vForEmpty) element.removeAttribute('v-for-empty');

      const fragment = document.createDocumentFragment();

      if (list.length === 0 && vForEmpty) {
        // 处理 v-for-empty
        const emptyNode = document.createElement(element.tagName === 'TR' ? 'td' : 'div');
        if (element.tagName === 'TR') {
          emptyNode.colSpan = element.querySelectorAll('td').length || 1;
          emptyNode.style.textAlign = "center";
        }
        emptyNode.textContent = vForEmpty;
        fragment.appendChild(emptyNode);
      } else {
        // 处理 v-for 数据
        for (const item of list) {
          const clone = element.cloneNode(true);

          // 替换 {{变量名}} - 使用合并的上下文（局部变量优先）
          const context = { ...data, [itemVar.trim()]: item };
          const textNodes = this._findTextNodes(clone);
          for (const node of textNodes) {
            node.textContent = node.textContent.replace(/\{\{([\w.]+)\}\}/g, (_, key) => {
              return this._getValueFromPath(context, key.trim());
            });
          }

          // 处理事件绑定
          this._processBindings(clone, context);
          fragment.appendChild(clone);
        }
      }

      // 替换原始元素
      const parentNode = element.parentNode;
      parentNode.replaceChild(fragment, element);
    }
  }

  /**
   * 处理单向绑定和事件绑定
   * @param {HTMLElement} element - 根元素
   * @param {object} data - 数据对象
   */
  _processBindings(element, data) {
    // 处理文本节点的单向绑定
    const textNodes = this._findTextNodes(element);
    for (const node of textNodes) {
      node.textContent = node.textContent.replace(/\{\{([\w.]+)\}\}/g, (_, key) => {
        return this._getValueFromPath(data, key.trim());
      });
    }

    // 处理事件绑定（仅对元素节点操作）
    if (element.nodeType === Node.ELEMENT_NODE) {
      const elementsWithEvents = element.querySelectorAll('[onclick], [onchange], [oninput], [onsubmit]');
      for (const el of elementsWithEvents) {
        const attributes = Array.from(el.attributes);
        for (const attr of attributes) {
          if (attr.name.startsWith('on')) {
            let handlerName = attr.value;
            // 替换事件绑定中的模板变量
            handlerName = handlerName.replace(/\{\{([\w.]+)\}\}/g, (_, key) => {
              return this._getValueFromPath(data, key.trim());
            });
            if (handlerName.startsWith("window.")) {
              continue;
            }
            // 替换为 window.函数名
            el.setAttribute(attr.name, `window.${handlerName}`);
          }
        }
      }

      // 处理 v-value 绑定（用于 select 标签）
      const selectElements = element.querySelectorAll('select[v-value]');
      for (const select of selectElements) {
        const valuePath = select.getAttribute('v-value');
        const value = this._getValueFromPath(data, valuePath.trim());
        if (value !== undefined) {
          const options = select.querySelectorAll('option');
          for (const option of options) {
            option.selected = option.value === value;
          }
        }
        select.removeAttribute('v-value');
      }
    }
  }

  /**
   * 查找所有文本节点
   * @param {HTMLElement} element - 根元素
   * @returns {Array} 文本节点列表
   */
  _findTextNodes(element) {
    const textNodes = [];
    const walk = (node) => {
      if (node.nodeType === Node.TEXT_NODE && node.textContent.trim() !== '') {
        textNodes.push(node);
      } else if (node.nodeType === Node.ELEMENT_NODE) {
        for (const child of node.childNodes) {
          walk(child);
        }
      }
    };

    walk(element);
    return textNodes;
  }

  /**
   * 根据路径获取对象值
   * @param {object} obj - 数据对象
   * @param {string} path - 路径（如 'user.name'）
   * @returns {any} 值
   */
  _getValueFromPath(obj, path) {
    return path.split('.').reduce((acc, key) => {
      return acc ? acc[key] : undefined;
    }, obj);
  }
}