/**
 * 简易模板引擎
 * 支持功能：
 * 1. 单向绑定（{{变量名}}）
 * 2. 事件绑定（事件名="函数名"）
 * 3. v-for 循环（v-for="item in items"）
 */

class Template {
  constructor(templateString) {
    this.templateString = templateString;
    this._vForCache = new Map(); // 缓存 v-for 解析结果
    this.compiled = this.compile(templateString);
  }

  /**
   * 编译模板
   * @param {string} template - 模板字符串
   * @returns {object} 编译结果对象
   */
  compile(template) {
    // 检查是否有 v-for
    const hasVFor = template.includes('v-for');

    // 解析模板为 DOM 树
    const templateElement = document.createElement("template");
    templateElement.innerHTML = template;
    const domTree = templateElement.content.firstElementChild;

    // 记录 v-for 元素
    let vForElements = [];
    if (hasVFor) {
      vForElements = this._findVForElements(domTree);
    }

    return {
      template,
      domTree,
      vForElements,
      hasVFor,
    };
  }

  /**
   * 渲染模板
   * @param {object} data - 数据对象
   * @returns {HTMLElement} 渲染后的 DOM 元素
   */
  render(data) {
    const { domTree, vForElements, hasVFor } = this.compiled;

    // 克隆 DOM 树
    const clonedTree = domTree.cloneNode(true);

    // 处理 v-for 元素
    if (hasVFor) {
      this._processVForElements(this.templateString, clonedTree, vForElements, data);
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
    for (const element of vForElements) {
      const vForValue = element.getAttribute('v-for');
      const cacheKey = template; // 使用 v-for 属性值作为缓存键

      let list;
      // 检查缓存
      if (this._vForCache.has(cacheKey)) {
        const [itemVar, listVar] = this._vForCache.get(cacheKey);
        list = data[listVar.trim()];
      } else {
        const [itemVar, listVar] = vForValue.split(' in ');
        this._vForCache.set(cacheKey, [itemVar, listVar]);
        list = data[listVar.trim()];
      }

      if (!list) {
        list = [];
      }
      if (!Array.isArray(list)) {
        console.error(`v-for 数据 ${listVar} 不是数组`);
        continue;
      }

      // 移除 v-for 属性
      element.removeAttribute('v-for');

      // 克隆并插入元素
      const parent = element.parentNode;
      const fragment = document.createDocumentFragment();

      for (const item of list) {
        const clone = element.cloneNode(true);

        // 替换 {{变量名}}
        const textNodes = this._findTextNodes(clone);
        for (const node of textNodes) {
          node.textContent = node.textContent.replace(/\{\{([\w.]+)\}\}/g, (_, key) => {
            return this._getValueFromPath(item, key.trim());
          });
        }

        fragment.appendChild(clone);
      }

      // 替换原始元素
      parent.replaceChild(fragment, element);
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
            const handlerName = attr.value;
            // 替换为 window.函数名
            el.setAttribute(attr.name, `window.${handlerName}`);
          }
        }
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
